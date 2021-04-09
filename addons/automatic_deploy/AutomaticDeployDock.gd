tool
extends Control

const NETLIFY_DOMAIN: String = "api.netlify.com"
const NETLIFY_DEFAULT_ENDPOINT: String = "api/v1"
const NETLIFY_URL: String = "https://" + NETLIFY_DOMAIN + "/" + NETLIFY_DEFAULT_ENDPOINT
const PAT_SETTINGS_PATH: String = "deploy/netlify/personal_access_token"
const SUBDOMAIN_SETTINGS_PATH: String = "deploy/netlify/subdomain"
const BUILD_OUTPUT_FOLDER: String = "user://builds/html5"

export (NodePath) var _api_token_edit_path
export (NodePath) var _log_label_path
export (NodePath) var _copy_site_button_path
export (NodePath) var _success_label_path
export (NodePath) var _error_label_path

var settings: EditorSettings = null

onready var _api_token_edit: LineEdit = get_node(_api_token_edit_path)
onready var _log_label: TextEdit = get_node(_log_label_path)
onready var _success_label: Label = get_node(_success_label_path)
onready var _error_label: Label = get_node(_error_label_path)
onready var _copy_site_button: Button = get_node(_copy_site_button_path)
onready var _request: HTTPRequest = $HTTPRequest

func _on_AccessTokenSite_pressed():
	OS.shell_open("https://app.netlify.com/user/applications#personal-access-tokens")

# flag set to true on the start of a deploy. if an error goes wrong will be set
# to false. if it's still true at the very end of a depoy, everything was successful,
# and the label can be hidden.
var _so_far_successful: bool = false
func _show_error(error: String):
	_so_far_successful = false
	_error_label.visible = true
	_error_label.text = error

func print_to_log(s1, s2="", s3="", s4="", s5=""):
	_log_label.text += str(s1, s2, s3, s4, s5) + "\n"

func clear_log():
	_log_label.text = ""

func _on_DeployButton_pressed():
	_success_label.visible = false
	clear_log()
	print_to_log("Deploying...")
	_so_far_successful = true
	
	var _must_create_site: bool = true
	var subdomain: String = ""
	if ProjectSettings.has_setting(SUBDOMAIN_SETTINGS_PATH):
		_must_create_site = false
		subdomain = ProjectSettings.get_setting(SUBDOMAIN_SETTINGS_PATH)

	# ensure the build directory exists
	var dir := Directory.new()
	dir.make_dir_recursive(BUILD_OUTPUT_FOLDER)
	
	# delete every file in the directory
	dir.open(BUILD_OUTPUT_FOLDER)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	
	# export the project with the godot executable
	var output = []
	var index_html_path: String = str(BUILD_OUTPUT_FOLDER, "/index.html")
	var exit_code: int = OS.execute(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), "--export-debug", "HTML5", ProjectSettings.globalize_path(index_html_path)], true, output)
	print_to_log("Exported using godot executable to ", ProjectSettings.globalize_path(index_html_path))
	if exit_code != 0:
		_show_error(str("Error exporting from godot, exit code: ", exit_code, ". Do you have an HTML5 export called HTML5 setup?"))
		return
		
	# zip it into a zip file TODO add linux and mac commands to do this
	output = []
	var target_zip_local_path: String = str(BUILD_OUTPUT_FOLDER, ".zip")
	var target_zip_path: String = ProjectSettings.globalize_path(target_zip_local_path).replace("/", "\\")
	var target_folder_path: String = ProjectSettings.globalize_path(BUILD_OUTPUT_FOLDER).replace("/", "\\")
	exit_code = OS.execute("CMD.exe", ["/C", "tar.exe", "-a", "-c", "-f", target_zip_path, target_folder_path], true, output)
	print_to_log("Zipped build folder with exit code: ", exit_code)

	if _must_create_site:
		print_to_log("Creating site...")
		var headers: Array = [
			"User-Agent: Godot",
			str("Authorization: Bearer ", _api_token_edit.text),
		]
		_request.request(NETLIFY_URL + "/sites", headers, true, HTTPClient.METHOD_POST, "{}")
		var data: Array = yield(_request, "request_completed")
		var response_code: int = data[1]
		print_to_log("Create site response code: ", response_code)
		print_to_log("Create site response body: ", (data[3] as PoolByteArray).get_string_from_utf8())
		if response_code != 201:
			_show_error("Error creating site, response code not 201!")
			return
		var response_body: Dictionary = parse_json((data[3] as PoolByteArray).get_string_from_utf8())
		subdomain = response_body["default_domain"]
		ProjectSettings.set_setting(SUBDOMAIN_SETTINGS_PATH, subdomain)
		_copy_site_button.visible = true
		
	var headers: Array = [
		"Content-Type: application/zip",
		str("Authorization: Bearer ", _api_token_edit.text),
	]
	var f := File.new()
	f.open(target_zip_local_path, File.READ)
	request_raw(headers, f.get_buffer(f.get_len()), str("sites/", subdomain, "/deploys"))
	f.close()
	
	if _so_far_successful:
		_error_label.visible = false
		var time: Dictionary = OS.get_time()
		_success_label.text = str("Successfully deployed at ", time["hour"], ":", time["minute"], ":", time["second"])
		_success_label.visible = true

# used for uploading zip of project
func request_raw(headers: Array, data: PoolByteArray, netlify_api_path: String):
	var err = 0
	var http = HTTPClient.new() # Create the Client.

	err = http.connect_to_host(NETLIFY_DOMAIN, -1, true) # Connect to host/port.
	assert(err == OK) # Make sure connection was OK.

	# Wait until resolved and connected.
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		print_to_log("Connecting...")
		if not OS.has_feature("web"):
			OS.delay_msec(500)
		else:
			yield(Engine.get_main_loop(), "idle_frame")

	print_to_log(http.get_status())
	assert(http.get_status() == HTTPClient.STATUS_CONNECTED) # Could not connect

	# Some headers

	err = http.request_raw(HTTPClient.METHOD_POST, "/" + NETLIFY_DEFAULT_ENDPOINT + "/" + netlify_api_path, headers, data) # Request a page from the site (this one was chunked..)
	assert(err == OK) # Make sure all is OK.

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		# Keep polling for as long as the request is being processed.
		http.poll()
		print_to_log("Requesting...")
		if not OS.has_feature("web"):
			OS.delay_msec(500)
		else:
			# Synchronous HTTP requests are not supported on the web,
			# so wait for the next main loop iteration.
			yield(Engine.get_main_loop(), "idle_frame")

	assert(http.get_status() == HTTPClient.STATUS_BODY or http.get_status() == HTTPClient.STATUS_CONNECTED) # Make sure request finished well.

	print_to_log(str("response? ", http.has_response())) # Site might not have a response.

	if http.has_response():
		# If there is a response...

		var response_headers: Dictionary = http.get_response_headers_as_dictionary() # Get response headers.
		print_to_log("code: ", http.get_response_code()) # Show response code.
		print_to_log("**headers:\\n", response_headers) # Show headers.

		# Getting the HTTP Body

		if http.is_response_chunked():
			# Does it use chunks?
			print_to_log("Response is Chunked!")
		else:
			# Or just plain Content-Length
			var bl = http.get_response_body_length()
			print_to_log("Response Length: ", bl)

		# This method works for both anyway

		var rb = PoolByteArray() # Array that will hold the data.

		while http.get_status() == HTTPClient.STATUS_BODY:
			# While there is body left to be read
			http.poll()
			# Get a chunk.
			var chunk = http.read_response_body_chunk()
			if chunk.size() == 0:
				if not OS.has_feature("web"):
					# Got nothing, wait for buffers to fill a bit.
					OS.delay_usec(1000)
				else:
					yield(Engine.get_main_loop(), "idle_frame")
			else:
				rb = rb + chunk # Append to read buffer.
		# Done!

		print_to_log("bytes got: ", rb.size())
		var text = rb.get_string_from_ascii()
		print_to_log("Text: ", text)

func _ready():
	_copy_site_button.visible = ProjectSettings.has_setting(SUBDOMAIN_SETTINGS_PATH)
	if settings != null:
		if PAT_SETTINGS_PATH in settings:
			_api_token_edit.text = settings.get(PAT_SETTINGS_PATH)
		else:
			settings.set(PAT_SETTINGS_PATH, "")
			settings.add_property_info({
				"name": PAT_SETTINGS_PATH,
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
				"hint_string": "personal access token from netlify"
			})

func _on_CopySiteButton_pressed():
	OS.clipboard = ProjectSettings.get(SUBDOMAIN_SETTINGS_PATH)

func _on_ApiTokenEdit_text_changed(new_text: String):
	settings.set(PAT_SETTINGS_PATH, new_text)
