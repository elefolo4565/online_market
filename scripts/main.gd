extends Control
## メインシーン — SceneManagerと連携して画面遷移を管理


func _ready() -> void:
	SceneManager.set_main_node(self)
	SceneManager.change_scene("title")
