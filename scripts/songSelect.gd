extends Control
class_name SongSelect

@export var chart_paths: Array[String] = [
	"res://charts/example_chart.json",
	"res://charts/example_chart2.json",
	"res://charts/SukerokuMeister.json"
]

var charts: Array[Dictionary] = []
var index: int = 0
var animating: bool = false

@onready var ctr          : Control             = $HSplitContainer
@onready var left_arrow   : Control             = $LeftArrow
@onready var right_arrow  : Control             = $RightArrow
@onready var jacket_rect  : TextureRect         = $HSplitContainer/Leftarea/CenterContainer/Jacket
@onready var title_lbl    : Label               = $HSplitContainer/Rightarea/TitleLbl
@onready var level_lbl    : Label               = $HSplitContainer/Rightarea/LevelLbl
@onready var bg_rect      : TextureRect         = $Background
@onready var preview      : AudioStreamPlayer2D = $Preview

func _ready() -> void:
	_preload_charts()
	_show_chart(index)
	_update_arrows()

func _preload_charts() -> void:
	charts.resize(chart_paths.size())
	for i in chart_paths.size():
		var meta = _load_meta(chart_paths[i])
		charts[i] = meta
		for key in ["jacket", "background", "song"]:
			var p: String = meta.get(key, "")
			if p != "":
				ResourceLoader.load_threaded_request(p)

func _unhandled_input(event: InputEvent) -> void:
	if animating:
		return
	if event.is_action_pressed("ui_right"):
		_switch_chart(1)
	elif event.is_action_pressed("ui_left"):
		_switch_chart(-1)
	elif event.is_action_pressed("ui_accept"):
		GameData.chart_path = chart_paths[index]
		GameData.chart_meta = charts[index]
		get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _update_arrows() -> void:
	left_arrow.visible  = index > 0
	right_arrow.visible = index < charts.size() - 1

func _switch_chart(delta: int) -> void:
	var new_index = (index + delta + charts.size()) % charts.size()
	if new_index == index:
		return

	animating = true
	var w = get_viewport_rect().size.x

	# ターゲット位置を if/else で設定
	var target_pos = Vector2.ZERO
	if delta > 0:
		# 右入力なら左へスライドアウト
		target_pos = Vector2(-w, 0)
	else:
		# 左入力なら右へスライドアウト
		target_pos = Vector2(w, 0)

	var tween = create_tween()
	tween.tween_property(ctr, "position", target_pos, 0.25)\
		 .set_trans(Tween.TRANS_SINE)\
		 .set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		_on_slide_out_finished(new_index, delta)
	)

func _on_slide_out_finished(new_index: int, delta: int) -> void:
	index = new_index
	_show_chart(index)
	_update_arrows()

	var w = get_viewport_rect().size.x

	# 逆側からスライドインする初期位置を if/else で設定
	if delta > 0:
		ctr.position = Vector2(w, 0)
	else:
		ctr.position = Vector2(-w, 0)

	var tween = create_tween()
	tween.tween_property(ctr, "position", Vector2.ZERO, 0.25)\
		 .set_trans(Tween.TRANS_SINE)\
		 .set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		animating = false
	)

func _load_meta(path: String) -> Dictionary:
	var text = FileAccess.get_file_as_string(path)
	var j = JSON.new()
	if j.parse(text) != OK:
		push_error("Chart JSON load failed: %s" % path)
		return {}
	return j.get_data() as Dictionary

func _get_res(path: String) -> Resource:
	if path == "":
		return null
	var res = ResourceLoader.load_threaded_get(path)
	if res == null:
		res = load(path)
	return res

func _show_chart(i: int) -> void:
	var meta: Dictionary = charts[i]

	# 画像＆背景
	jacket_rect.texture = _get_res(meta.get("jacket", "")) as Texture2D
	bg_rect.texture     = _get_res(meta.get("background", "")) as Texture2D

	# タイトル＆レベル
	title_lbl.text = meta.get("title", "NO TITLE")
	level_lbl.text = "LEVEL %s" % str(meta.get("level", 1))

	# プレビュー再生
	var song_path: String = meta.get("song", "")
	if song_path != "":
		var stream = _get_res(song_path) as AudioStream
		if stream and preview.stream != stream:
			preview.stop()
			preview.stream = stream
			preview.play()
	else:
		preview.stop()
