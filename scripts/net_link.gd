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
signal attack_received(word: String, tier: int)
signal salvo_received(word: String, count: int)
signal pressure_received(source: String)
signal opponent_topped_out
signal state_received(payload: Dictionary)

enum Backend { ROOM, DIRECT }

const PORT := 8642
const CONFIG_PATH := "user://player.cfg"

## The orchestration server that hands out room codes and brokers the punchthrough.
## foxssake run a public one; point this at your own before shipping.
const NORAY_HOST := "tomfol.io"
const NORAY_PORT := 8890

## Four boards at once means the host takes three challengers.
const MAX_PEERS := 3

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
## peer id -> {"name": String, "ready": bool}. Everyone in the room but you.
var roster: Dictionary = {}

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
	if which == Backend.ROOM:
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
	if which == Backend.ROOM:
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
	# Accept a code however it arrives — chunked off the screen, or pasted with
	# stray whitespace around it.
	_host_code = code.strip_edges().replace(" ", "")
	_relay_tried = false
	active = true
	is_host = false
	_join_countdown = ROOM_JOIN_TIMEOUT
	status = "knocking on %s" % _host_code.to_upper()
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
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_join_countdown = 0.0
	active = false
	is_host = false
	connected = false
	roster.clear()
	room_code = ""
	_host_code = ""
	_relay_tried = false
	my_ready = false


func both_ready() -> bool:
	return everyone_ready()


func set_ready(value: bool) -> void:
	my_ready = value
	if connected:
		net_ready.rpc(value)
	room_changed.emit()
	if is_host and everyone_ready():
		net_begin.rpc(peer_ids())
		match_begin.emit()


func _on_peer_connected(id: int) -> void:
	connected = true
	_tighten_timeout(id)
	roster[id] = {"name": "…", "ready": false}
	status = "%d in the room" % (roster.size() + 1)
	net_hello.rpc(my_name)
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


func _on_peer_disconnected(id: int) -> void:
	var who: String = String(roster[id]["name"]) if roster.has(id) else "a rival"
	roster.erase(id)
	# In a crowd, one person leaving is not the end of the match.
	if roster.is_empty():
		_drop("%s disconnected" % who)
	else:
		status = "%s left" % who
		peer_left.emit("%s left" % who)
		room_changed.emit()


func _drop(why: String) -> void:
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


# ---------------------------------------------------------------- lobby protocol

@rpc("any_peer", "call_remote", "reliable")
func net_hello(who: String) -> void:
	_note_name(multiplayer.get_remote_sender_id(), who)
	# Answer so whoever connected later still learns the earlier names.
	net_hello_back.rpc(my_name)
	room_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func net_hello_back(who: String) -> void:
	_note_name(multiplayer.get_remote_sender_id(), who)
	room_changed.emit()


func _note_name(id: int, who: String) -> void:
	var clean := who.strip_edges().substr(0, 14)
	if clean == "":
		clean = "RIVAL"
	if not roster.has(id):
		roster[id] = {"name": clean, "ready": false}
	else:
		roster[id]["name"] = clean


@rpc("any_peer", "call_remote", "reliable")
func net_ready(value: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if roster.has(id):
		roster[id]["ready"] = value
	room_changed.emit()
	if is_host and everyone_ready():
		net_begin.rpc(peer_ids())
		match_begin.emit()


@rpc("any_peer", "call_remote", "reliable")
func net_begin(_ids: Array) -> void:
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

func send_attack(to_peer: int, word: String, tier: int) -> void:
	if connected and roster.has(to_peer):
		net_attack.rpc_id(to_peer, word, tier)


func send_salvo(to_peer: int, word: String, count: int) -> void:
	if connected and roster.has(to_peer):
		net_salvo.rpc_id(to_peer, word, count)


func send_pressure(source: String) -> void:
	if connected:
		net_pressure.rpc(source)


func send_topped_out() -> void:
	if connected:
		net_lost.rpc()


func send_state(payload: Dictionary) -> void:
	if connected:
		net_state.rpc(payload)


@rpc("any_peer", "call_remote", "reliable")
func net_attack(word: String, tier: int) -> void:
	attack_received.emit(word, tier)


@rpc("any_peer", "call_remote", "reliable")
func net_salvo(word: String, count: int) -> void:
	salvo_received.emit(word, count)


@rpc("any_peer", "call_remote", "reliable")
func net_pressure(source: String) -> void:
	pressure_received.emit(source)


@rpc("any_peer", "call_remote", "reliable")
func net_lost() -> void:
	opponent_topped_out.emit()


## Cosmetic mirror. Unreliable — a lost frame is a lost frame, not a lost block.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func net_state(payload: Dictionary) -> void:
	payload["from"] = multiplayer.get_remote_sender_id()
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
