extends Node
## Autoload `Store`. The one purchase this game has, and the receipt in front of
## it.
##
## There is exactly one product — the premium pack — and it is non-consumable, so
## the whole of what this file does is: find out what Apple charges for it, ask
## Apple to sell it, and hand `Profile.grant` the result once a transaction
## verifies. Everything the pack unlocks was already written and gated on
## `Profile.owns(PACK_PREMIUM)`; nothing downstream knows StoreKit exists.
##
## ## What "verified" means here, and what it does not
##
## StoreKit 2 verifies the signature on a transaction before it reaches us, and
## the plugin routes anything that fails to `unverified_transaction_updated`
## rather than to `purchase_completed`. So an unsigned or tampered transaction
## never lands on the success path — which is the protection worth having in a
## game with no server and nothing to steal but three cosmetics and an ad break.
##
## It is *not* server-side receipt validation, and it cannot be: that needs a
## backend, and there is no backend. A determined person with a jailbroken phone
## can grant themselves the pack. That is an acceptable loss for what is being
## sold; the alternative is running a server to protect the price of a coffee.
##
## ## Why entitlements are asked for at launch
##
## A non-consumable is owned forever and across devices, so a fresh install on a
## new phone has to arrive already owning it. `fetch_current_entitlements` is
## what makes that true without the player having to know the words "restore
## purchases" — the button exists as well, because Apple requires it, but it
## should be the thing nobody ever needs.
##
## Guarded on the platform like everything else Apple-shaped in this project: the
## desktop stub registers the classes and then refuses to construct them, so
## `available()` checks the platform first and the construction second.

signal changed

## The product id, which must match App Store Connect exactly. Apple's own
## convention is a reverse-DNS suffix on the bundle id, and a mismatch here is
## indistinguishable from a product that has not finished propagating — both
## come back `INVALID_PRODUCT`.
const PREMIUM_ID := "com.damonj.wordwars.premium"

enum State { OFF, LOADING, READY, BUYING, FAILED }

var state: int = State.OFF
## What the store row says about itself. Never empty once `_ready` has run.
var status := "not available"

## Apple's own localised price string — "£1.99", "$2.99", "¥300". Shown rather
## than a hardcoded price, because the number differs per storefront and getting
## it wrong is a refund request.
var price := ""

var _manager: StoreKitManager
var _product: StoreProduct = null


func available() -> bool:
	if not (OS.get_name() in ["iOS", "macOS"]):
		return false
	return ClassDB.can_instantiate("StoreKitManager")


func _ready() -> void:
	if not available():
		_note(State.OFF, "the store needs an iPhone or a Mac")
		return
	_manager = StoreKitManager.new()
	if _manager == null:
		_note(State.OFF, "the store is unavailable on this build")
		return

	_manager.products_request_completed.connect(_on_products)
	_manager.purchase_completed.connect(_on_purchased)
	_manager.restore_completed.connect(_on_restored)
	_manager.transaction_updated.connect(_on_transaction)
	_manager.unverified_transaction_updated.connect(_on_unverified)
	# Started before anything is asked for. `start` is what attaches the listener
	# for transactions that finish outside the app — an Ask to Buy approval that
	# lands days later, or a purchase interrupted by a crash — and one that
	# arrives with nothing listening is a purchase the player has paid for and
	# not received.
	_manager.start()
	_manager.fetch_current_entitlements()
	_note(State.LOADING, "asking the App Store")
	_manager.request_products(PackedStringArray([PREMIUM_ID]))


## Whether there is something to sell. False while loading, and false forever on
## a device where the product does not exist — the settings row uses this to
## decide whether to offer anything at all.
func can_buy() -> bool:
	return state == State.READY and _product != null \
		and not Profile.owns(Profile.PACK_PREMIUM)


func buy() -> void:
	if not can_buy():
		return
	_note(State.BUYING, "asking the App Store")
	_manager.purchase(_product)


## Apple requires a restore control, and it has to work even when there is
## nothing to restore. Safe to press at any time.
func restore() -> void:
	if not available():
		return
	_note(State.BUYING, "restoring")
	_manager.restore_purchases()


# ------------------------------------------------------------------ callbacks

func _on_products(products: Array, status_code: int) -> void:
	if status_code != StoreKitManager.StoreKitStatus.OK or products.is_empty():
		# The commonest cause by a distance is a product that exists in App Store
		# Connect but has not propagated yet, which can take hours on a first
		# submission and looks exactly like a wrong id. Said plainly, because a
		# store row reading "unavailable" with no reason is a bug report.
		_note(State.FAILED, "the pack is not available right now")
		print("[Store] products request failed — status %d, %d returned" % [
			status_code, products.size()])
		return
	for p in products:
		if p is StoreProduct and String((p as StoreProduct).product_id) == PREMIUM_ID:
			_product = p
			price = String((p as StoreProduct).display_price)
	if _product == null:
		_note(State.FAILED, "the pack is not available right now")
		return
	print("[Store] premium pack available at %s" % price)
	_note(State.READY, price)


func _on_purchased(transaction: StoreTransaction, status_code: int,
		error_message: String) -> void:
	match status_code:
		StoreKitManager.StoreKitStatus.OK:
			_award(transaction, "purchase")
		StoreKitManager.StoreKitStatus.USER_CANCELLED, \
				StoreKitManager.StoreKitStatus.CANCELLED:
			# Not a failure and must not read as one. Backing out of Apple's sheet
			# is an answer, and an error message for it is the app telling somebody
			# off for changing their mind.
			_note(State.READY, price)
		StoreKitManager.StoreKitStatus.PURCHASE_PENDING:
			# Ask to Buy, waiting on a parent. The transaction arrives later
			# through `transaction_updated`, which is why `start` runs at launch.
			_note(State.READY, "waiting for approval")
		_:
			print("[Store] purchase failed — status %d: %s" % [
				status_code, error_message])
			_note(State.FAILED, "that did not go through")


## Anything Apple hands over outside a purchase this session: a restore, an
## entitlement found at launch, a deferred approval, a purchase made on another
## device. All of them mean the same thing and take the same path.
func _on_transaction(transaction: StoreTransaction) -> void:
	_award(transaction, "transaction")


func _on_restored(status_code: int, error_message: String) -> void:
	if status_code != StoreKitManager.StoreKitStatus.OK:
		print("[Store] restore failed — status %d: %s" % [status_code, error_message])
		_note(State.READY if _product != null else State.FAILED,
			"nothing to restore")
		return
	# The entitlements themselves arrive through `transaction_updated`, so this
	# only reports the outcome. Owning it already is the successful case.
	_note(State.READY if _product != null else State.OFF,
		"restored" if Profile.owns(Profile.PACK_PREMIUM) else "nothing to restore")
	changed.emit()


func _on_unverified(transaction: StoreTransaction, verification_error: int) -> void:
	# Never granted. StoreKit could not vouch for this, and the one thing a store
	# with no server must not do is take an unverifiable transaction's word for it.
	print("[Store] refusing unverified transaction for %s — error %d" % [
		String(transaction.product_id), verification_error])


## The one place a pack is ever handed over.
##
## `revocation_date` is checked as well as the id: Apple sets it on a refunded or
## family-revoked purchase, and a refund that leaves the pack in place is a
## refund the player was paid for.
func _award(transaction: StoreTransaction, how: String) -> void:
	if String(transaction.product_id) != PREMIUM_ID:
		return
	if transaction.revocation_date > 0.0:
		print("[Store] %s revoked — taking the pack back" % how)
		Profile.revoke(Profile.PACK_PREMIUM)
		_note(State.READY if _product != null else State.OFF, price)
		changed.emit()
		return
	print("[Store] premium pack granted by %s" % how)
	Profile.grant(Profile.PACK_PREMIUM)
	_note(State.READY if _product != null else State.OFF, "owned")
	changed.emit()


func _note(next: int, text: String) -> void:
	state = next
	status = text
	print("[Store] %s — %s" % [State.keys()[next], text])
	changed.emit()
