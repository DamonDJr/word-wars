extends Node
## Autoload `Link`. Owns the connection, the lobby protocol and every packet the
## game sends. `game.gd` talks to this and never touches a peer directly.
##
## The whole point of the split is that Word Wars runs on Godot's high-level
## multiplayer, so the transport is the *only* thing a different backend changes.
## Epic Online Services, Steam and ENet all hand you a MultiplayerPeer; swap the
## object and every RPC below keeps working untouched. `_make_peer()` is the seam.

signal peer_joined
signal peer_left(reason: String)
signal room_changed
signal match_begin
signal rematch_agreed
signal attack_received(word: String, tier: int, victim: int)
## Somebody's board overfilled, and this attack is why. Sent by the machine that
## owns the board that just topped out, because that is the only one that knows
## — a board is simulated on exactly one machine, so the attacker never sees the
## landing. `culprit` is the entity that sent the block.
signal topout_credit(culprit: int)
signal salvo_received(word: String, count: int, victim: int)
signal pressure_received(source: String)
signal opponent_topped_out
signal state_received(payload: Dictionary)

## ROOM  — noray orchestration + ENet punchthrough. Codes are the orchestrator's
##         own ids, so they are long and there is no way to browse rooms.
## DIRECT — dial an address. LAN or a forwarded port, no third party.
## EOS    — Epic lobbies over `EOSGMultiplayerPeer`. Short codes and a browsable
##         room list, because the code is just a lobby attribute we choose.
##
## Every one of these ends up as a MultiplayerPeer, so the RPCs below never learn
## which is in play.
enum Backend { ROOM, DIRECT, EOS }

const PORT := 8642
const CONFIG_PATH := "user://player.cfg"

## The orchestration server that hands out room codes and brokers the punchthrough.
## foxssake run a public one; point this at your own before shipping.
const NORAY_HOST := "tomfol.io"
const NORAY_PORT := 8890

## Codes people read out loud, so the alphabet drops every glyph that gets
## misheard or mistyped: no O/0, no I/1. Five characters over 32 symbols is
## ~33.5 million combinations, which is far more than enough for the number of
## rooms open at once and short enough to say down a phone.
const EOS_CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const EOS_CODE_LENGTH := 5
## A freshly created lobby is not searchable for a few seconds. Without retries
## the very first thing anyone tries — host, then join from the other machine —
## reports "no such room", which reads as a broken code rather than a slow index.
const EOS_SEARCH_TRIES := 5
const EOS_SEARCH_GAP := 2.0

## Mirrors the orchestration server's NORAY_OID_CHARSET, and must not disagree
## with it. Leave it empty while NORAY_HOST points at a server handing out the
## nanoid default — 21 characters of mixed case, where only the server knows
## which of `k` and `K` it issued, so the only safe thing a client can do is pass
## a code through exactly as typed.
##
## Set it to the single-case alphabet you configured and the lobby starts
## tidying up what the player types: upper-casing it, and dropping the hyphens
## and spaces people add when reading a code out. That is sound only because
## upper-casing a single-case alphabet cannot lose information. See
## `deploy/README.md` for the server side and the rest of the checklist.
const CODE_ALPHABET := ""

## Four boards at once means the host takes three challengers.
const MAX_PEERS := 3
## Boards are identified by "entity id": a real peer id for a person, a negative
## number for a bot. Bots live on the host, which simulates them and speaks for
## them, so every board still has exactly one machine in charge of it.
const SEATS := 4

var backend: int = Backend.ROOM
var room_code := ""          # our own code, shown when hosting
var active := false
var _host_code := ""         # the code we are dialling
var _relay_tried := false
var is_host := false
var connected := false
var status := ""

var my_name := "PLAYER"
var my_ready := false
## What kind of machine somebody is playing on.
##
## Typing on glass is roughly half the speed of typing on keys, which in a game
## about typing fast is not a small difference — so the room says who is on what
## rather than leaving it to be discovered in the first thirty seconds of a
## match. `touch` is the half that matters for balance; the rest is a label.
enum Device { KEYS, TOUCH }

static func my_device() -> int:
	match OS.get_name():
		"iOS", "Android":
			return Device.TOUCH
	return Device.KEYS


## What to call it on screen.
static func device_label(dev: int) -> String:
	return "PHONE" if dev == Device.TOUCH else "KEYBOARD"


## peer id -> {"name": String, "ready": bool, "device": int}. Everyone but you.
var roster: Dictionary = {}
## How many CPUs the host is adding to fill the room out.
var bot_count := 0
## Special block kinds the host has switched on. Everyone plays the host's
## rules — a match where two people disagree about whether armour exists is not
## one match — so this is pushed out and clients only ever read it.
var kinds: Array = []
## Agreed seating for the current match: [{"id": int, "name": String}, ...].
var seating: Array = []

## Kept so the one-on-one code paths still read naturally.
var peer_name: String:
	get:
		for id in roster:
			return String(roster[id]["name"])
		return ""
var peer_ready: bool:
	get:
		for id in roster:
			return bool(roster[id]["ready"])
		return false


func peer_ids() -> Array:
	var ids := roster.keys()
	ids.sort()
	return ids


func everyone_ready() -> bool:
	if roster.is_empty() or not my_ready:
		return false
	for id in roster:
		if not roster[id]["ready"]:
			return false
	return true

## ENet keeps retrying a dead address for a long time before it gives up, which
## leaves someone who mistyped an address staring at "connecting" forever.
const JOIN_TIMEOUT := 8.0
## Punchthrough plus a relay fallback needs longer than a plain dial.
const ROOM_JOIN_TIMEOUT := 25.0
var _join_countdown := 0.0


func _process(delta: float) -> void:
	if _join_countdown > 0.0:
		_join_countdown -= delta
		if _join_countdown <= 0.0 and active and not connected and not is_host:
			leave()
			status = ("nobody answered that code — is it right and are they hosting?"
				if backend == Backend.ROOM
				else "no answer from there — is the host running and reachable?")
			room_changed.emit()


func _ready() -> void:
	_load_name()
	Noray.on_connect_nat.connect(_on_noray_nat)
	Noray.on_connect_relay.connect(_on_noray_relay)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_host)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_host_vanished)


# ------------------------------------------------------------------- connection
#
# Two ways in. ROOM goes through a noray orchestration server: it hands each host
# a code, then brokers a UDP punchthrough between the two players, falling back
# to relaying through itself when their networks refuse to cooperate. Either way
# the result is an ordinary ENetMultiplayerPeer, so nothing downstream changes.
# DIRECT skips all of that and dials an address, which is only useful on a LAN or
# a forwarded port but needs no third party at all.

func host(which: int) -> void:
	leave()
	backend = which
	if which == Backend.EOS:
		_host_by_eos()
	elif which == Backend.ROOM:
		_host_by_code()
	else:
		var enet := ENetMultiplayerPeer.new()
		if enet.create_server(PORT, MAX_PEERS) != OK:
			status = "could not open port %d — already hosting?" % PORT
			room_changed.emit()
			return
		multiplayer.multiplayer_peer = enet
		active = true
		is_host = true
		status = "waiting for a challenger on port %d" % PORT
		room_changed.emit()


func join(which: int, address: String) -> void:
	leave()
	backend = which
	if which == Backend.EOS:
		_join_by_eos(address)
	elif which == Backend.ROOM:
		_join_by_code(address)
	else:
		var enet := ENetMultiplayerPeer.new()
		if enet.create_client(address, PORT) != OK:
			status = "could not reach %s" % address
			room_changed.emit()
			return
		multiplayer.multiplayer_peer = enet
		active = true
		is_host = false
		_join_countdown = JOIN_TIMEOUT
		status = "connecting to %s" % address
		room_changed.emit()


# ------------------------------------------------------------------ room codes

## True when the server behind `NORAY_HOST` issues codes a person can read out.
## The lobby asks this rather than measuring a code's length, because the answer
## has to be the same before any code exists.
## `which` asks about a backend other than the live one.
##
## The lobby needs this *before* anyone connects — while a code is still being
## typed — and at that point `backend` is whatever the last session left behind.
## Passing the backend the menu is offering gets the right answer for a session
## that hasn't started yet.
func short_codes(which := -1) -> bool:
	var b: int = backend if which < 0 else which
	# EOS codes come from our own alphabet above, so they are always tidy.
	if b == Backend.EOS:
		return true
	return CODE_ALPHABET != ""


## Accepts a code however it arrives. Whitespace always goes — one chunked for
## reading, or pasted with a stray newline, is still the same code. Hyphens and
## case are only touched when the alphabet says touching them is safe: `-` is a
## real character in nanoid's default alphabet, so stripping it there would turn
## a valid code into one that does not exist.
func clean_code(raw: String, which := -1) -> String:
	var out := raw.strip_edges().replace(" ", "").replace("\t", "").replace("\n", "")
	if not short_codes(which):
		return out
	return out.replace("-", "").to_upper()


## Reach the orchestration server and claim a code plus a punched-open UDP port.
## Both roles need this before anything else can happen.
func _reach_noray() -> bool:
	if Noray.is_connected_to_host() and Noray.local_port > 0:
		return true

	status = "reaching the lobby server"
	room_changed.emit()

	if await Noray.connect_to_host(NORAY_HOST, NORAY_PORT) != OK:
		status = "could not reach the lobby server at %s" % NORAY_HOST
		leave()
		room_changed.emit()
		return false

	Noray.register_host()
	await Noray.on_pid

	if await Noray.register_remote() != OK:
		status = "the lobby server would not register us"
		leave()
		room_changed.emit()
		return false
	return true


func _host_by_code() -> void:
	if not await _reach_noray():
		return

	# Host on the very port noray just punched open, or the hole is useless.
	var enet := ENetMultiplayerPeer.new()
	if enet.create_server(Noray.local_port, MAX_PEERS) != OK:
		status = "could not host on port %d" % Noray.local_port
		leave()
		room_changed.emit()
		return

	multiplayer.multiplayer_peer = enet
	active = true
	is_host = true
	room_code = Noray.oid
	status = "share your code — waiting for a challenger"
	room_changed.emit()


func _join_by_code(code: String) -> void:
	if not await _reach_noray():
		return
	_host_code = clean_code(code)
	_relay_tried = false
	active = true
	is_host = false
	_join_countdown = ROOM_JOIN_TIMEOUT
	# Show the code as it is actually being sent. Prettying it up here would mean
	# the one thing on screen during a failed join is not what went out.
	status = "knocking on %s" % _host_code
	room_changed.emit()
	Noray.connect_nat(_host_code)


## noray tells both sides where to aim. The host only has to punch; the client
## punches and then dials.
func _on_noray_nat(address: String, port: int) -> void:
	var err := await _shake_hands(address, port)
	if err != OK and not is_host and not _relay_tried:
		# Punchthrough refused. Relaying through noray is slower but works.
		_relay_tried = true
		status = "direct route blocked — relaying"
		room_changed.emit()
		Noray.connect_relay(_host_code)


func _on_noray_relay(address: String, port: int) -> void:
	await _shake_hands(address, port)


func _shake_hands(address: String, port: int) -> Error:
	if Noray.local_port <= 0 or not active:
		return ERR_UNCONFIGURED

	if is_host:
		var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if peer == null:
			return ERR_UNCONFIGURED
		return await PacketHandshake.over_enet_peer(peer, address, port)

	# Client: knock first from the same local port ENet is about to dial out of.
	var udp := PacketPeerUDP.new()
	udp.bind(Noray.local_port)
	udp.set_dest_address(address, port)
	var err := await PacketHandshake.over_packet_peer(udp)
	udp.close()
	# ERR_BUSY means the hole is half open, which is often still enough.
	if err != OK and err != ERR_BUSY:
		return err

	var enet := ENetMultiplayerPeer.new()
	if enet.create_client(address, port, 0, 0, 0, Noray.local_port) != OK:
		return ERR_CANT_CONNECT
	multiplayer.multiplayer_peer = enet
	return OK


func leave() -> void:
	# No-op on ENet and for clients; only a host ever holds a lobby.
	_destroy_lobby()
	_reset_room()
	# Never tear the peer down inline — see `_release_peer`.
	_release_peer.call_deferred()


## Drop the ENet peer, one frame late, deliberately.
##
## `leave()` is reachable from `peer_disconnected`, `server_disconnected` and
## `connection_failed`, and all three are emitted while ENet is still walking
## the event queue that produced them. Closing and freeing the peer during that
## walk is a use-after-free inside the native library: it takes the whole
## process down on Windows and macOS, with no Godot-level error, so it presents
## as the game simply vanishing rather than as a script bug.
##
## Deferring puts the teardown after the queue has drained. State is still reset
## immediately above, so the UI reacts on the same frame the player left.
func _release_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func _reset_room() -> void:
	_join_countdown = 0.0
	active = false
	is_host = false
	connected = false
	roster.clear()
	seating.clear()
	bot_count = 0
	kinds.clear()
	room_code = ""
	_host_code = ""
	_relay_tried = false
	my_ready = false


## Free chairs the host can drop a CPU into.
func free_seats() -> int:
	return maxi(0, SEATS - 1 - roster.size())


func set_bots(n: int) -> void:
	if not is_host:
		return
	bot_count = clampi(n, 0, free_seats())
	net_bots.rpc(bot_count)
	room_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func net_bots(n: int) -> void:
	bot_count = n
	room_changed.emit()


## The host decides which special blocks are in play and tells the room. Sent on
## change and again in the seating, so a peer that joined late still arrives at
## the countdown holding the same rules as everybody else.
func set_kinds(list: Array) -> void:
	if not is_host:
		return
	kinds = list.duplicate()
	net_kinds.rpc(kinds)
	room_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func net_kinds(list: Array) -> void:
	kinds = list.duplicate()
	room_changed.emit()


## The host lays out who sits where, once, and tells everyone. Clients cannot
## work this out for themselves any more: bots have no peer id to sort by.
func _build_seating() -> Array:
	var out: Array = [{"id": multiplayer.get_unique_id(), "name": my_name,
		"kinds": kinds, "device": my_device()}]
	for id in peer_ids():
		out.append({"id": id, "name": String(roster[id]["name"]),
			"device": int(roster[id].get("device", Device.KEYS))})
	# CPUs are named for the personality they will play as, and the host decides
	# once so everybody in the room sees the same table. The name is the whole
	# message: the host configures its bots straight back off these labels.
	var picks: Array = AiOpponent.ROSTER.duplicate()
	picks.shuffle()
	for i in bot_count:
		# A CPU runs on whoever is hosting, so it types at whatever speed it was
		# built for and gets no label and no handicap either way.
		out.append({"id": -(i + 1), "name": String(picks[i % picks.size()]).to_upper(),
			"device": Device.KEYS})
	return out


func both_ready() -> bool:
	return everyone_ready()


func set_ready(value: bool) -> void:
	my_ready = value
	if connected:
		net_ready.rpc(value)
	room_changed.emit()
	if is_host and everyone_ready():
		seating = _build_seating()
		net_begin.rpc(seating)
		match_begin.emit()


func _on_peer_connected(id: int) -> void:
	connected = true
	_tighten_timeout(id)
	roster[id] = {"name": "…", "ready": false, "device": Device.KEYS}
	status = "%d in the room" % (roster.size() + 1)
	net_hello.rpc(my_name, my_device())
	# Whoever just arrived does not know the house rules yet.
	if is_host:
		net_kinds.rpc_id(id, kinds)
	peer_joined.emit()
	room_changed.emit()


func _on_connected_to_host() -> void:
	connected = true
	_tighten_timeout(1)
	status = "connected"
	net_hello.rpc(my_name)
	peer_joined.emit()
	room_changed.emit()


func _on_connect_failed() -> void:
	status = "connection failed — check the address and that they are hosting"
	leave()
	room_changed.emit()


func _on_host_vanished() -> void:
	_drop("the host closed the game")


## Somebody else's connection went away.
##
## Nobody's room ends here. An empty roster used to mean "drop everything",
## which in a two-player game fired the instant the only guest left: the host
## was ejected from their own lobby, and the inline teardown that followed took
## the guest's client down with it. An empty room is a room waiting for someone.
##
## A guest's room ends only when the *host* goes, and that arrives separately as
## `server_disconnected` — see `_on_host_vanished`. Another guest leaving is
## just news either way, so both roles are handled the same.
func _on_peer_disconnected(id: int) -> void:
	var who: String = String(roster[id]["name"]) if roster.has(id) else "a rival"
	roster.erase(id)
	status = "%s left" % who
	peer_left.emit("%s left" % who)
	room_changed.emit()


func _drop(why: String) -> void:
	# The host vanishing raises both `peer_disconnected` and
	# `server_disconnected`, so this can be reached twice for one event.
	if not active:
		return
	leave()
	status = why
	peer_left.emit(why)
	room_changed.emit()


## ENet waits the better part of a minute before calling a silent peer dead,
## which leaves the survivor typing into a match nobody is playing.
func _tighten_timeout(id: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null:
		return
	# A client is only actually connected to the host, yet it still gets told
	# about every other client. Asking ENet for a peer it has no link to is an
	# error, so only tighten the ones we really hold.
	if not is_host and id != 1:
		return
	var pp := enet.get_peer(id)
	if pp != null:
		pp.set_timeout(1500, 2000, 6000)


# ------------------------------------------------------------------------- EOS
#
# Epic lobbies serve two different jobs at once, which is what makes short codes
# and a room browser fall out of the same mechanism:
#
#   bucket_id            the private room code, looked up directly
#   BROWSE_KEY attribute a tag every Word Wars lobby carries, so one attribute
#                        search returns every open room
#
# The lobby is only ever a directory entry. Once a client has the host's product
# user id, traffic goes over `EOSGMultiplayerPeer` and every RPC in this file
# behaves exactly as it does on ENet.

var _eos_ready := false
## Only the host holds this. Clients never create a lobby.
var _lobby: HLobby = null


## Bring the platform up and sign in, once per run.
##
## Device ID sign-in, so there is no Epic account, no login screen and no
## password anywhere — appropriate for a game people open to play one round.
func _ensure_eos() -> bool:
	if _eos_ready:
		return true
	if not EOSConfig.is_configured():
		status = "Epic is not set up yet — fill in scripts/eos_config.gd"
		leave()
		room_changed.emit()
		return false

	status = "connecting to Epic"
	room_changed.emit()
	if not await HPlatform.setup_eos_async(EOSConfig.make_credentials()):
		status = "could not start Epic Online Services"
		leave()
		room_changed.emit()
		return false

	status = "signing in"
	room_changed.emit()
	if not await HAuth.login_anonymous_async(my_name):
		# Overwhelmingly the cause is portal-side rather than anything local.
		status = "Epic sign-in failed — check the client policy allows Device ID and Lobbies"
		leave()
		room_changed.emit()
		return false

	_eos_ready = true
	return true


func _mint_code() -> String:
	var code := ""
	for _i in EOS_CODE_LENGTH:
		code += EOS_CODE_ALPHABET[randi() % EOS_CODE_ALPHABET.length()]
	return code


func _host_by_eos() -> void:
	if not await _ensure_eos():
		return

	var code := _mint_code()
	status = "opening the room"
	room_changed.emit()

	var opts := EOS.Lobby.CreateLobbyOptions.new()
	opts.bucket_id = code
	opts.max_lobby_members = SEATS
	opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.presence_enabled = true

	var lobby: HLobby = await HLobbies.create_lobby_async(opts)
	if lobby == null:
		status = "Epic would not open a room"
		leave()
		room_changed.emit()
		return
	_lobby = lobby

	var peer := EOSGMultiplayerPeer.new()
	if peer.create_server(EOSConfig.SOCKET) != OK:
		status = "could not open the Epic network socket"
		leave()
		room_changed.emit()
		return
	# Without this the host has to answer each connection request by hand, and
	# joiners simply hang.
	peer.set_auto_accept_connection_requests(true)

	multiplayer.multiplayer_peer = peer
	active = true
	is_host = true
	room_code = code
	status = "share your code — waiting for a challenger"
	room_changed.emit()


func _join_by_eos(code: String) -> void:
	if not await _ensure_eos():
		return

	var wanted := clean_code(code, Backend.EOS)
	_host_code = wanted
	active = true
	is_host = false
	# The generic join timeout stays off while searching: the retry loop below is
	# already bounded, and letting `_process` fire mid-search would abandon a
	# lookup that was about to succeed.
	_join_countdown = 0.0
	status = "looking for %s" % wanted
	room_changed.emit()

	var lobbies = null
	for attempt in EOS_SEARCH_TRIES:
		lobbies = await HLobbies.search_by_bucket_id_async(wanted)
		if lobbies != null and not lobbies.is_empty():
			break
		# The player can back out mid-search; do not resurrect a dead attempt.
		if not active:
			return
		if attempt < EOS_SEARCH_TRIES - 1:
			status = "looking for %s (%d)" % [wanted, attempt + 2]
			room_changed.emit()
			await get_tree().create_timer(EOS_SEARCH_GAP).timeout
			if not active:
				return

	if lobbies == null or lobbies.is_empty():
		status = "no room with code %s — is it right, and are they still hosting?" % wanted
		leave()
		room_changed.emit()
		return

	var host_puid: String = lobbies[0].owner_product_user_id
	if host_puid == "":
		status = "that room has no host"
		leave()
		room_changed.emit()
		return

	var peer := EOSGMultiplayerPeer.new()
	if peer.create_client(EOSConfig.SOCKET, host_puid) != OK:
		status = "could not reach the host"
		leave()
		room_changed.emit()
		return

	multiplayer.multiplayer_peer = peer
	_join_countdown = ROOM_JOIN_TIMEOUT
	status = "connecting"
	room_changed.emit()


## Tear down the lobby we host, so leaving actually closes the room.
##
## Skipping this leaves the entry sitting in the browser — and answering to its
## code — until Epic times it out, so the next person to try that code connects
## to nothing. Fire-and-forget is deliberate: the request goes out before the
## coroutine's first await, and `leave()` must not become async for its callers.
## Owner-gated inside EOSG, so a client reaching here is harmless.
func _destroy_lobby() -> void:
	if _lobby == null:
		return
	var lobby := _lobby
	_lobby = null
	lobby.destroy_async()


# ---------------------------------------------------------------- lobby protocol

@rpc("any_peer", "call_remote", "reliable")
func net_hello(who: String, dev: int = Device.KEYS) -> void:
	_note_name(multiplayer.get_remote_sender_id(), who, dev)
	# Answer so whoever connected later still learns the earlier names.
	net_hello_back.rpc(my_name, my_device())
	room_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func net_hello_back(who: String, dev: int = Device.KEYS) -> void:
	_note_name(multiplayer.get_remote_sender_id(), who, dev)
	room_changed.emit()


func _note_name(id: int, who: String, dev: int = Device.KEYS) -> void:
	var clean := who.strip_edges().substr(0, 14)
	if clean == "":
		clean = "RIVAL"
	if not roster.has(id):
		roster[id] = {"name": clean, "ready": false, "device": dev}
	else:
		roster[id]["name"] = clean
		roster[id]["device"] = dev


@rpc("any_peer", "call_remote", "reliable")
func net_ready(value: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if roster.has(id):
		roster[id]["ready"] = value
	room_changed.emit()
	if is_host and everyone_ready():
		seating = _build_seating()
		net_begin.rpc(seating)
		match_begin.emit()


@rpc("any_peer", "call_remote", "reliable")
func net_begin(plan: Array) -> void:
	seating = plan
	match_begin.emit()


@rpc("any_peer", "call_remote", "reliable")
func net_rematch() -> void:
	my_ready = false
	for id in roster:
		roster[id]["ready"] = false
	rematch_agreed.emit()


func request_rematch() -> void:
	my_ready = false
	peer_ready = false
	if connected:
		net_rematch.rpc()
	rematch_agreed.emit()


# ------------------------------------------------------------------ match packets

## `victim` is an entity id. A person receives it directly; a bot's mail goes to
## the host, which owns it.
func send_attack(victim: int, word: String, tier: int) -> void:
	if not connected:
		return
	if victim > 0:
		net_attack.rpc_id(victim, word, tier, 0)
	else:
		net_attack.rpc_id(1, word, tier, victim)


func send_salvo(victim: int, word: String, count: int) -> void:
	if not connected:
		return
	if victim > 0:
		net_salvo.rpc_id(victim, word, count, 0)
	else:
		net_salvo.rpc_id(1, word, count, victim)


func send_pressure(source: String) -> void:
	if connected:
		net_pressure.rpc(source)


func send_topped_out() -> void:
	if connected:
		net_lost.rpc()


func send_state(payload: Dictionary) -> void:
	if connected:
		net_state.rpc(payload)


## Tell whoever caused a topout that they caused it. Their machine holds their
## score, so the bonus can only be paid there.
func send_topout(culprit: int) -> void:
	if not connected or culprit <= 0:
		return
	net_topout.rpc_id(culprit)


@rpc("any_peer", "call_remote", "reliable")
func net_topout() -> void:
	topout_credit.emit(multiplayer.get_unique_id())


@rpc("any_peer", "call_remote", "reliable")
func net_attack(word: String, tier: int, victim: int) -> void:
	attack_received.emit(word, tier, victim)


@rpc("any_peer", "call_remote", "reliable")
func net_salvo(word: String, count: int, victim: int) -> void:
	salvo_received.emit(word, count, victim)


@rpc("any_peer", "call_remote", "reliable")
func net_pressure(source: String) -> void:
	pressure_received.emit(source)


@rpc("any_peer", "call_remote", "reliable")
func net_lost() -> void:
	opponent_topped_out.emit()


## Cosmetic mirror. Unreliable — a lost frame is a lost frame, not a lost block.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func net_state(payload: Dictionary) -> void:
	# "own" lets the host speak for its bots; otherwise it is just the sender.
	if not payload.has("own"):
		payload["own"] = multiplayer.get_remote_sender_id()
	state_received.emit(payload)


# ------------------------------------------------------------------ name storage

func set_name_and_save(value: String) -> void:
	my_name = value
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", my_name)
	cfg.save(CONFIG_PATH)


func _load_name() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		my_name = str(cfg.get_value("player", "name", "PLAYER"))
