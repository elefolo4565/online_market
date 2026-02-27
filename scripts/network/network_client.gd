extends Node
class_name NetworkClient
## WebSocket接続管理

signal connected()
signal disconnected()
signal connection_error(message: String)
signal message_received(type: String, data: Dictionary)

const PRODUCTION_URL: String = "wss://elefolo2.com/ws/online_market"
const LOCAL_URL: String = "ws://localhost:8080"
var DEFAULT_URL: String = PRODUCTION_URL if OS.has_feature("web") else LOCAL_URL

var _socket: WebSocketPeer = WebSocketPeer.new()
var _url: String = DEFAULT_URL
var _is_connected: bool = false
var _is_connecting: bool = false


func connect_to_server(url: String = "") -> void:
	if url.is_empty():
		url = _url
	else:
		_url = url

	if _is_connected or _is_connecting:
		close()

	_is_connecting = true
	var err: int = _socket.connect_to_url(url)
	if err != OK:
		_is_connecting = false
		connection_error.emit("接続に失敗しました")


func close() -> void:
	if _is_connected or _is_connecting:
		_socket.close()
	_is_connected = false
	_is_connecting = false


func is_connected_to_server() -> bool:
	return _is_connected


func send_message(type: String, data: Dictionary = {}) -> void:
	if not _is_connected:
		return
	data["type"] = type
	var json_str: String = JSON.stringify(data)
	_socket.send_text(json_str)


# --- 便利メソッド ---

func create_room(player_name: String, player_count: int, ai_difficulty: int) -> void:
	send_message(NetworkProtocol.CREATE_ROOM, {
		"player_name": player_name,
		"player_count": player_count,
		"ai_difficulty": ai_difficulty,
	})


func join_room(room_code: String, player_name: String) -> void:
	send_message(NetworkProtocol.JOIN_ROOM, {
		"room_code": room_code,
		"player_name": player_name,
	})


func auto_match(player_name: String, player_count: int) -> void:
	send_message(NetworkProtocol.AUTO_MATCH, {
		"player_name": player_name,
		"player_count": player_count,
	})


func cancel_match() -> void:
	send_message(NetworkProtocol.CANCEL_MATCH)


func add_ai(ai_difficulty: int) -> void:
	send_message(NetworkProtocol.ADD_AI, {"ai_difficulty": ai_difficulty})


func remove_ai() -> void:
	send_message(NetworkProtocol.REMOVE_AI)


func start_game() -> void:
	send_message(NetworkProtocol.START_GAME)


func submit_bid(card_value: int) -> void:
	send_message(NetworkProtocol.SUBMIT_BID, {"card_value": card_value})


func leave() -> void:
	send_message(NetworkProtocol.LEAVE)


# --- ポーリング処理 ---

func _process(_delta: float) -> void:
	_socket.poll()

	var state: WebSocketPeer.State = _socket.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if _is_connecting:
				_is_connecting = false
				_is_connected = true
				connected.emit()

			while _socket.get_available_packet_count() > 0:
				var raw: String = _socket.get_packet().get_string_from_utf8()
				_handle_message(raw)

		WebSocketPeer.STATE_CLOSING:
			pass

		WebSocketPeer.STATE_CLOSED:
			if _is_connected or _is_connecting:
				var code: int = _socket.get_close_code()
				_is_connected = false
				_is_connecting = false
				if code != -1:
					disconnected.emit()
				else:
					connection_error.emit("接続が切断されました")


func _handle_message(raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null or not parsed is Dictionary:
		return

	var data: Dictionary = parsed as Dictionary
	var msg_type: String = data.get("type", "") as String
	if msg_type.is_empty():
		return

	message_received.emit(msg_type, data)
