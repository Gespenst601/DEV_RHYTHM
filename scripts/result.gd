extends Control
@onready var bg_rect : TextureRect = $BgRect
@onready var title_label  : Label = $VBoxContainer/TitleLbl
@onready var rank_label   : Label    = $VBoxContainer/RankLbl
@onready var score_label  : Label    = $VBoxContainer/ScoreLbl
@onready var comment_label: Label    = $VBoxContainer/CommentLbl

func _ready() -> void:
	var meta  := GameData.chart_meta
	var stats := GameData.play_stats

	# 背景画像が指定されていれば差し替え
	var bg_path : String = meta.get("background", "")
	if bg_path != "":
		bg_rect.texture = load(bg_path)

	# 曲名
	if has_node("TitleLbl"):
		%TitleLbl.text = meta.get("title", "Unknown")

	# スコアとランク
	var score : int = stats.get("score", 0)
	var rank  : String = _rank_text(score)

	if has_node("RankLbl"):
		%RankLbl.text = rank
	if has_node("ScoreLbl"):
		%ScoreLbl.text = "Score : " + str(score)

	# コメント
	if has_node("CommentLbl"):
		%CommentLbl.text = _rank_comment(rank)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scenes/SongSelect.tscn")

# ────────────────────────────────
func _rank_text(s: int) -> String:
	if    s >= 1_000_000: return "SS"
	elif  s >=   950_000: return "S"
	elif  s >=   900_000: return "A"
	elif  s >=   850_000: return "B"
	elif  s >=   800_000: return "C"
	else:                 return "D"

func _rank_comment(r: String) -> String:
	return {
		"SS": "Perfect!! 最高だ！",
		"S":  "ほぼ完璧！",
		"A":  "いい感じ！",
		"B":  "もう一息！",
		"C":  "練習あるのみ！",
		"D":  "次は頑張ろう！"
	}.get(r, "")
