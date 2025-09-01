class_name AvatarsTask
extends RefCounted

signal completed(task_response)

enum Task {
	GET_CREDIT_CARD,
	GET_BROWSER_ICON,
	GET_COUNTRY_FLAG,
	GET_AVATAR_IMAGE,
	GET_FAVICON,
	GET_QR,
	GET_INITIALS
}

var _code : int
var _method : HTTPClient.Method
var _endpoint : String
var _headers : PackedStringArray
var _payload : Dictionary

# EXPOSED VARIABLES ---------------------------------------------------------
var response : Dictionary
var error : Dictionary
# ---------------------------------------------------------------------------

var _handler : HTTPRequest

func _init(code : int, endpoint : String, headers : PackedStringArray,  payload : Dictionary = {}, bytepayload: PackedByteArray = []):
	_code = code
	_endpoint = endpoint
	_headers = headers
	_payload = payload
	_method = match_code(code)

func match_code(code : int) -> int:
	match code:
		_: return HTTPClient.METHOD_GET

func push_request(httprequest : HTTPRequest) -> void:
	_handler = httprequest
	httprequest.request_completed.connect(_on_task_completed)
	httprequest.request(_endpoint, _headers, _method, JSON.new().stringify(_payload))

func _on_task_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	if result > 0: 
		complete({}, {result = result, message = "HTTP Request Error"})
		return
	var is_valid: bool = JSON.new().parse(body.get_string_from_utf8()) == Error.OK
	var result_body: Dictionary = JSON.parse_string(body.get_string_from_utf8()) if is_valid else {error = is_valid}
	if response_code in [200, 201, 204]:
		var image: Image = Image.new()
		var err: int = image.load_png_from_buffer(body)
		if err == OK:
			var file_name: String = get_header_value("Content-Disposition: ", headers)
			var texture: ImageTexture = ImageTexture.new()
			texture.create_from_image(image)
			result_body = { 
			image = image,
			texture = texture
			}
		else:
			result_body = {
				message = "Could not load image",
				code = err
			   }
		complete(result_body)
	else:
		complete({}, result_body)

func complete(_result: Dictionary = response,  _error : Dictionary = error) -> void:
	response = _result
	error = _error
	if _handler : _handler.queue_free()
	emit_signal("completed", TaskResponse.new(response, error))


func get_header_value(_header: String, headers : PackedStringArray) -> String:
	for header in headers:
		if header.begins_with(_header):
			return header.trim_prefix(_header)
	return ""
