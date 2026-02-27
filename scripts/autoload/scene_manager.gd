extends Node
## 画面遷移マネージャー（Autoload）

const SCENES: Dictionary = {
	"title": "res://scenes/ui/title_screen.tscn",
	"lobby": "res://scenes/ui/lobby_screen.tscn",
	"online_lobby": "res://scenes/ui/online_lobby_screen.tscn",
	"game": "res://scenes/ui/game_screen.tscn",
	"result": "res://scenes/ui/result_screen.tscn",
}

var _current_scene: Node = null
var _transition_params: Dictionary = {}
var _main_node: Node = null


func _ready() -> void:
	GameEvents.scene_change_requested.connect(_on_scene_change_requested)
	GameEvents.back_to_title_requested.connect(_on_back_to_title)


func set_main_node(main: Node) -> void:
	_main_node = main


func change_scene(scene_name: String, params: Dictionary = {}) -> void:
	_transition_params = params
	if _current_scene:
		_current_scene.queue_free()
		await _current_scene.tree_exited
	if not SCENES.has(scene_name):
		push_error("Unknown scene: " + scene_name)
		return
	var scene_res: PackedScene = load(SCENES[scene_name]) as PackedScene
	_current_scene = scene_res.instantiate()
	if _main_node:
		_main_node.add_child(_current_scene)
	else:
		get_tree().root.add_child(_current_scene)
	if _current_scene.has_method("init_with_params"):
		_current_scene.init_with_params(params)


func get_params() -> Dictionary:
	return _transition_params


func _on_scene_change_requested(scene_name: String, params: Dictionary) -> void:
	change_scene(scene_name, params)


func _on_back_to_title() -> void:
	change_scene("title")
