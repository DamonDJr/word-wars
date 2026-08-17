class_name EOSConfig
extends RefCounted
## Epic Online Services credentials for Word Wars, from the Epic Dev Portal.
##
## These are EOS *game-client* credentials: they are meant to ship inside the
## build, so a player can read them out of any copy of the game. That makes them
## not-a-secret in the sense that matters, but they still identify your product,
## and the client secret in particular should not be pasted into public issues.
##
## Word Wars needs its **own product** in the Dev Portal. Do not reuse the Veil
## of Echoes credentials — lobbies are scoped per deployment, so sharing them
## would put both games' players in the same lobby pool and let one game's
## searches turn up the other's rooms.
##
## Fill these in at: https://dev.epicgames.com/portal → your product →
## Product Settings. You need Product ID, Sandbox ID, Deployment ID, and a
## client with its ID and secret.
##
## Until they are filled in, `is_configured()` returns false and `net_link.gd`
## quietly keeps using the existing noray backend — so this file landing in the
## repo changes nothing about how the game currently plays.

const PRODUCT_ID := "132b4916da7c400dbf38bee36395ccd9"
const SANDBOX_ID := "91684d8c3c914880a68feeed293dbd8f"
const DEPLOYMENT_ID := "969a99adde824f598413c9c7280eb252"
const CLIENT_ID := "xyza78913YRRJM5ZZ7wMR90RqFihBz6a"
const CLIENT_SECRET := "Elb09DlideD0erPcdAVzwEI1eA/PNJHvsmazJDMya4w"

const PRODUCT_NAME := "Word Wars"
const PRODUCT_VERSION := "0.19.0"

## Name of the P2P socket. Host and clients must agree, and it is scoped to the
## deployment, so it only has to be unique within this product.
const SOCKET := "wordwars"

## Every Word Wars lobby carries this attribute, which is what makes a single
## search return "all the open rooms" for the browser. The room code lives in
## the lobby's bucket_id instead, so a code lookup and a browse are two different
## queries against the same lobby.
const BROWSE_KEY := "WWGAME"
const BROWSE_VALUE := "1"


## True once real credentials are present. Everything EOS-related is gated on
## this so an unconfigured checkout behaves exactly as it did before.
static func is_configured() -> bool:
	return PRODUCT_ID != "" and CLIENT_ID != "" and CLIENT_SECRET != ""


static func make_credentials() -> HCredentials:
	var c := HCredentials.new()
	c.product_id = PRODUCT_ID
	c.sandbox_id = SANDBOX_ID
	c.deployment_id = DEPLOYMENT_ID
	c.client_id = CLIENT_ID
	c.client_secret = CLIENT_SECRET
	c.product_name = PRODUCT_NAME
	c.product_version = PRODUCT_VERSION
	return c
