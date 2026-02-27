extends Node
## グローバルイベントバス（Autoload）
## 画面遷移やUI間の疎結合な通信に使用

signal scene_change_requested(scene_name: String, params: Dictionary)
signal back_to_title_requested()
signal sfx_requested(sfx_name: String)
signal bgm_requested(bgm_name: String)
signal bg_color_changed(color: Color)
