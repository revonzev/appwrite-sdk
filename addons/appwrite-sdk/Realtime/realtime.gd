class_name AppwriteRealtime
extends Node

signal subscribed()
signal unsubscribed(channels)
signal received_error(error)
signal received_updates(updates)

const _BASE_URL: String = "/realtime"

var _client = WebSocketPeer.new()
var subscribed_channels: Array = []

func _ready():
	_client.connection_closed.connect(_closed)
	_client.connection_error.connect(_closed)
	_client.connection_established.connect(_connected)
	_client.data_received.connect(_on_data)

func subscribe(channels: Array) -> bool:
	var endpoint: String = get_parent().endpoint_realtime
	var project_param: String = "project=%s&" % get_parent().get_project()
	var channels_param: String = ""
	subscribed_channels += channels
	for channel in subscribed_channels: channels_param+="channels[]=%s&" % channel
	var url: String = endpoint + _BASE_URL + "?" + project_param + channels_param
	var err: int = _client.connect_to_url(url)
	set_process(!bool(err))
	return !bool(err)

func unsubscribe(channels: Array = []) -> void:
	if channels.is_empty():
		_client.disconnect_from_host(1000, "Client ubsubscribed.")
	else:
		for channel in channels: subscribed_channels.erase(channel)
		subscribe([])
	unsubscribed.emit(channels)

func _closed(was_clean = false):
	received_error.emit({ was_clean = was_clean })
	unsubscribed.emit()
	set_process(false)

func _connected(proto = ""):
	subscribed.emit()
	
func _on_data():
	var data: String = _client.get_peer(1).get_packet().get_string_from_utf8()
	received_updates.emit(JSON.parse_string(data))

func _process(delta):
	_client.poll()
