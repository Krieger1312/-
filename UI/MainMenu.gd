extends Control
## Bootstrap screen: the only place in the project that calls
## NetworkManager.host_game()/join_game(). Without this there was no way to
## actually start a session by pressing Play -- NetworkManager only reacts
## to those calls, it never makes them itself.

const MAP_SCENE: String = "res://Maps/NovozybkovGreybox.tscn"

@onready var _nickname_edit: LineEdit = $VBox/NicknameEdit
@onready var _ip_edit: LineEdit = $VBox/IpEdit
@onready var _status_label: Label = $VBox/StatusLabel
@onready var _host_button: Button = $VBox/HostButton
@onready var _join_button: Button = $VBox/JoinButton


func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)


func _on_host_pressed() -> void:
	var err: Error = NetworkManager.host_game(_nickname_edit.text)
	if err != OK:
		_status_label.text = "Host failed (error %d)" % err
		return
	get_tree().change_scene_to_file(MAP_SCENE)


func _on_join_pressed() -> void:
	_status_label.text = "Connecting..."
	_join_button.disabled = true
	var err: Error = NetworkManager.join_game(_ip_edit.text, _nickname_edit.text)
	if err != OK:
		_status_label.text = "Join failed (error %d)" % err
		_join_button.disabled = false


func _on_connected_to_server() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)


func _on_connection_failed() -> void:
	_status_label.text = "Could not connect to server."
	_join_button.disabled = false
