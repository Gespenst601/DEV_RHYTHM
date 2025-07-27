
extends Node
signal note_judged(result: String, lane)

@export var chart_path       : String      = "res://charts/example_chart.json"
@export var note_scene       : PackedScene = preload("res://rhythm/Note.tscn")
@export var hold_note_scene  : PackedScene = preload("res://scenes/HoldNote.tscn")

func _ready() -> void:
	var chart := _load_chart(chart_path)
	for note_dict in chart["notes"]:
		var t: String = note_dict.get("type", "normal")
		var scene_to_spawn: PackedScene = hold_note_scene if t == "hold" else note_scene
		var n: Node2D     = scene_to_spawn.instantiate()

		# ---------------- 共通プロパティ ----------------
		n.hit_time_ms = note_dict["time"] * 1000.0 + Settings.user_offset_ms

		# lane は数値 or "special" のどちらかに正規化
		var lane_raw = note_dict["lane"]
		n.lane = lane_raw if lane_raw is String else int(lane_raw)

		# Note.tscn だけが持つ note_type
		if t != "hold":
			n.note_type = t
		else:
			# ホールドだけ長さを追加で渡す
			n.duration_ms = note_dict.get("duration", 0.0) * 1000.0

		n.position.x = _lane_to_x(n.lane)
		add_child(n)
		n.connect("note_judged", Callable(self, "_relay_note_judged"))

# ------------------------------------------------------------
func _relay_note_judged(result: String, lane) -> void:
	emit_signal("note_judged", result, lane)
# ------------------------------------------------------------
# あとの _load_chart() と _lane_to_x() は元のまま



# JSONロード（既存のまま）
func _load_chart(path: String) -> Dictionary:
	var txt = FileAccess.open(path, FileAccess.READ).get_as_text()
	return JSON.parse_string(txt)

# レーン番号→X座標変換（既存のまま）
func _lane_to_x(l) -> float:
	var start_x = Settings.center_x - 1.5 * Settings.lane_spacing
	match l:
		0:
			return start_x + 0 * Settings.lane_spacing
		1:
			return start_x + 1 * Settings.lane_spacing
		2:
			return start_x + 2 * Settings.lane_spacing
		3:
			return start_x + 3 * Settings.lane_spacing
		"special":
			return Settings.center_x
		_:
			return Settings.center_x
