class_name StorageTask
extends RefCounted

signal completed(task_response)

enum Task {
	CREATE_FILE,
	LIST_FILES,
	GET_FILE,
	GET_FILE_VIEW,
	GET_FILE_PREVIEW,
	UPDATE_FILE,
	DELETE_FILE,
	DOWNLOAD_FILE,
}

var _code : int
var _method : HTTPClient.Method
var _endpoint : String
var _headers : PackedStringArray
var _payload : Dictionary
var _bytepayload : PackedByteArray

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
	_bytepayload = bytepayload
	_method = match_code(code)

func match_code(code : int) -> int:
	match code:
		Task.CREATE_FILE:
			return HTTPClient.METHOD_POST
		Task.DELETE_FILE:
			return HTTPClient.METHOD_DELETE
		Task.UPDATE_FILE: 
			return HTTPClient.METHOD_PUT
		Task.UPDATE_FILE:
			return HTTPClient.METHOD_PATCH
		_: return HTTPClient.METHOD_GET

func push_request(httprequest : HTTPRequest) -> void:
	_handler = httprequest
	httprequest.request_completed.connect(_on_task_completed)
	if not _bytepayload.is_empty():
		var err = httprequest.request(_endpoint, _headers, _method, _bytepayload.get_string_from_ascii())
	else:
		httprequest.request(_endpoint, _headers, _method, JSON.new().stringify(_payload))

func _on_task_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	if result > 0: 
		complete({}, {result = result, message = "HTTP Request Error"})
		return
	var is_valid: bool = JSON.new().parse(body.get_string_from_utf8()) == Error.OK
	var result_body: Dictionary = JSON.parse_string(body.get_string_from_utf8()) if is_valid else {error = is_valid}
	if response_code in [200, 201, 204]:
		if _code in [Task.DOWNLOAD_FILE, Task.GET_FILE_VIEW, Task.GET_FILE_PREVIEW]:
			var file_name: String = get_header_value("Content-Disposition: ", headers)
			result_body = { 
			file_name = file_name.split('"')[1] if file_name!="" else "",
			file_binary = body,
			file_text = body.get_string_from_utf8(),
			file_type = get_header_value("Content-Type: ", headers)
			}
		complete(result_body)
	else:
		complete({}, result_body)

func complete(_result: Dictionary = response,  _error : Dictionary = error) -> void:
	response = _result
	error = _error
	if _handler : _handler.queue_free()
	completed.emit(TaskResponse.new(response, error))


func get_header_value(_header: String, headers : PackedStringArray) -> String:
	for header in headers:
		if header.begins_with(_header):
			return header.trim_prefix(_header)
	return ""
