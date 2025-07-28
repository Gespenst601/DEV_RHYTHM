extends Node2D
#──────────────────────────────────────
#  Rhythm Prototype – Game core script
#    - 読み込む譜面・BGM・背景は GameData.chart_meta で指定
#    - READY→GO! カウントのあと Conductor.play() 開始
#    - 曲終了 or 最後のノーツ処理後 Result へ遷移
#──────────────────────────────────────

enum GameState { INTRO, PLAYING, FINISHED }

## ノード参照
@onready var conductor      : Node            = $Conductor
@onready var audio_player   : AudioStreamPlayer = $AudioStreamPlayer
@onready var note_spawner   : Node            = $NoteSpawner
@onready var lane_renderer  : Node2D          = $LaneRenderer
@onready var bg_sprite      : TextureRect     = $CenterContainer/Background
@onready var score_label    : Label           = $ScoreLabel
@onready var ready_label    : Label           = $CenterContainer/ReadyLabel
@onready var judge_label    : Label           = $CenterContainer/JudgeLabel
# デバッグ表示用ラベル
@onready var debug_label: Label = $DebugLabel 

var judge_tween : Tween
var state: GameState = GameState.INTRO

# スコア・判定数
var score := 0
var total_great := 0
var total_good  := 0
var total_miss  := 0

#──────────────────────────────────────
func _ready() -> void:
	# ─ 曲・背景ロード ─
	var meta = GameData.chart_meta
	if meta.has("background") and meta["background"] != "":
		bg_sprite.texture = load(meta["background"])

	if meta.has("song") and meta["song"] != "":
		audio_player.stream = load(meta["song"])

	# ─ 譜面パスを NoteSpawner に渡す ─
	note_spawner.chart_path = GameData.chart_path
	note_spawner.connect("note_judged", _on_note_judged)

	# GUI ラベル初期位置
	_center_label(ready_label,  Settings.judge_line_y - 200)
	_center_label(judge_label, Settings.judge_line_y - 120)
	ready_label.visible = false
	judge_label.visible = false

	# カウントダウン
	_start_countdown()
	
	# デバッグラベルの設定
	if debug_label:
		debug_label.position = Vector2(20, 200)
		debug_label.size = Vector2(400, 200)
		debug_label.modulate = Color.YELLOW

#──────────────────────────────────────
## 入力受付（PLAYING 中のみ）
func _unhandled_input(e: InputEvent) -> void:
	if state != GameState.PLAYING:
		return

	if e.is_action_pressed("lane0"):
		_flash_lane(0, 0.2)
		_try_hit_lane(0)
	if e.is_action_pressed("lane1"):
		_flash_lane(1, 0.2)
		_try_hit_lane(1)
	if e.is_action_pressed("lane2"):
		_flash_lane(2, 0.2)
		_try_hit_lane(2)
	if e.is_action_pressed("lane3"):
		_flash_lane(3, 0.2)
		_try_hit_lane(3)
	if e.is_action_pressed("special"):
		_flash_lane("special", 0.2)
		_try_hit_lane("special")


#──────────────────────────────────────
## READY → GO! カウント
func _start_countdown() -> void:
	state = GameState.INTRO
	ready_label.visible = true
	ready_label.text  = "READY"
	ready_label.scale = Vector2.ONE * 1.6
	_center_pivot(ready_label)

	var tw := create_tween()
	tw.tween_property(ready_label, "scale", Vector2.ONE, 0.3)\
	  .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_callback(func():
		ready_label.text  = "GO!"
		ready_label.scale = Vector2.ONE * 1.6
		_center_pivot(ready_label)
	)
	tw.tween_property(ready_label, "scale", Vector2.ONE, 0.2)
	tw.tween_interval(0.5)
	tw.tween_callback(_begin_play)

func _begin_play() -> void:
	ready_label.visible = false
	conductor.play()
	audio_player.play()
	state = GameState.PLAYING

#──────────────────────────────────────
## 毎フレーム監視：曲が終わったらリザルトへ
func _process(delta: float) -> void:
	if state == GameState.PLAYING and not audio_player.playing:
		_go_result()
		
	# デバッグ情報更新
	_update_debug_info()

#──────────────────────────────────────
## 判定シグナル
func _on_note_judged(result: String, lane) -> void:
	match result:
		"Great":
			score += 2
			total_great += 1
			_flash_lane(lane)
		"Good":
			score += 1
			total_good += 1
			_flash_lane(lane, 0.5)
		"Miss":
			total_miss += 1
			_flash_lane(lane, 0.2)

	_show_judge(result)
	score_label.text = "Score: %d" % score

#──────────────────────────────────────
#  レーン発光
func _flash_lane(lane, strength := 1.0) -> void:
	if lane is float:                # ← ★ 追加 ★
		lane = int(lane)
	if lane is int:
		lane_renderer.flash(lane, strength)
	elif lane == "special":
		lane_renderer.flash_wide(strength)

#──────────────────────────────────────
#  判定文字演出
func _show_judge(text: String) -> void:
	if judge_tween and judge_tween.is_running():
		judge_tween.kill()

	judge_label.text = text
	match text:
		"Great": judge_label.modulate = Color("#4af")
		"Good":  judge_label.modulate = Color("#6f6")
		"Miss":  judge_label.modulate = Color("#f44")

	judge_label.scale = Vector2.ONE * 1.4
	_center_pivot(judge_label)
	judge_label.visible = true
	judge_label.modulate.a = 1.0

	judge_tween = create_tween()
	judge_tween.tween_property(judge_label, "scale", Vector2.ONE, 0.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	judge_tween.tween_interval(0.15)
	judge_tween.tween_property(judge_label, "modulate:a", 0.0, 0.25)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	judge_tween.tween_callback(Callable(judge_label, "hide"))

#──────────────────────────────────────
#  ノーツ判定の最近接探索
func _try_hit_lane(lane):
	var closest: Node2D = null
	var min_diff := 1e9
	var key := str(lane)
	for n in note_spawner.get_children():
		if n.judged: continue
		if str(n.lane) != key: continue
		var d = abs(conductor.get_time_ms() - n.hit_time_ms)
		if d < min_diff:
			min_diff = d
			closest  = n
	if closest:
		closest.try_hit()

#──────────────────────────────────────
#  結果画面へ遷移
func _go_result() -> void:
	if state == GameState.FINISHED:
		return
	state = GameState.FINISHED

	GameData.play_stats = {
		"score": score,
		"great": total_great,
		"good":  total_good,
		"miss":  total_miss
	}
	get_tree().change_scene_to_file("res://scenes/Result.tscn")

#──────────────────────────────────────
#  Label 位置・pivot 補助
func _center_label(label: Label, y: float) -> void:
	_center_pivot(label)
	label.position = Vector2(Settings.center_x, y)

func _center_pivot(label: Label) -> void:
	var size := label.get_minimum_size()
	label.pivot_offset = size / 2.0
	


func _update_debug_info() -> void:
	if not debug_label:
		return
		
	var debug_text = ""
	debug_text += "Time: %.1f ms\n" % conductor.get_time_ms()
	debug_text += "State: %s\n" % GameState.keys()[state]
	
	# アクティブなホールドノーツの情報
	var hold_notes = []
	for child in note_spawner.get_children():
		if child is HoldNote and not child.judged:
			hold_notes.append(child)
	
	debug_text += "Active Hold Notes: %d\n" % hold_notes.size()
	
	for i in range(min(3, hold_notes.size())):  # 最大3個まで表示
		var note = hold_notes[i]
		debug_text += "  Note %d: Lane %s, Hit %.1f ms\n" % [i, str(note.lane), note.hit_time_ms]
		debug_text += "    Head judged: %s, Holding: %s\n" % [note._head_judged, note._holding]
	
	debug_label.text = debug_text

# キー入力状態の可視化
func _show_input_state() -> void:
	var inputs = []
	for i in range(4):
		if Input.is_action_pressed("lane%d" % i):
			inputs.append(str(i))
	if Input.is_action_pressed("special"):
		inputs.append("SP")
	
	if inputs.size() > 0:
		print("Pressed: ", inputs.join(", "))
