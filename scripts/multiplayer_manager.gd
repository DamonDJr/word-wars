extends Node

signal lobby_started
signal player_connected(player)
signal player_disconnected(player)
signal match_ready
signal data_received(data, player)
signal match_error(error)

var game_center: GameCenterManager
var current_match: GKMatch

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	game_center = GameCenterManager.new()
	game_center.authenticate()
	
	print("Game Center initialized")

func find_match() -> void:
	var request := GKMatchRequest.new()
	
	request.min_players = 2
	request.max_players = 2
	request.invite_message = "Join my Word Wars battle!"
	
	GKMatchmakerViewController.request_match(
		request,
		_matchmaker_finished
	)
	
	lobby_started.emit()
	
func _matchmaker_finished(match: GKMatch, error: Variant) -> void:
	if error:
		print("Matchmaking error: ", error)
		match_error.emit(error)
		return
		
	current_match = match
	
	print("Match created!")
	
	current_match.data_received.connect(_on_data_received)
	current_match.player_changed.connect(_on_player_changed)
	current_match.did_fail_with_error.connect(_on_match_error)
	
	match_ready.emit()

func _on_player_changed(player: GKPlayer, connected: bool) -> void:
	print(
		"Player ",
		player.display_name,
		" connected: ",
		connected
	)
	
	if connected:
		player_connected.emit(player)
	else:
		player_disconnected.emit(player)

func _on_data_received(
	data: PackedByteArray,
	player: GKPlayer
) -> void:
	var json = JSON.parse_string(
		data.get_string_from_utf8()
	)
	
	if json == null:
		return
	
	data_received.emit(json, player)

func _on_match_error(error: String) -> void:
	print("Match error: ", error)
	match_error.emit(error)

func send(data: PackedByteArray) -> void:
	if current_match == null:
		return
	
	current_match.send_data_to_all_players(
		data,
		GKMatch.SendDataMode.RELIABLE
	)

func leave_match() -> void:
	if current_match:
		current_match.disconnect()
		current_match = null

func send_event(type: String, payload: Dictionary = {}) -> void:
	if current_match == null:
		return
	
	var packet := {
		"type": type,
		"payload": payload
	}
	
	var data := JSON.stringify(packet).to_utf8_buffer()
	
	current_match.send_data_to_all_players(
		data,
		GKMatch.SendDataMode.RELIABLE
	)
