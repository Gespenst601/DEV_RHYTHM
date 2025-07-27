extends Node2D
class_name HoldNote
signal note_judged(result: String, lane)

@export var duration_ms: float = 0.0   # NoteSpawner から渡ってくる
var hit_time_ms: float                 # 同上
var lane                             := 0        # 0-3 / "special"
var judged                            := false   # 最終判定が終わったら true

#@onready var SPAWN_Y: float = Settings.judge_line_y - 1500.0   # ← ホールドノーツの待機位置。落ちてくる感覚に影響！
const SPAWN_Y := -100.0              # ⇑を没にして通常ノーツと揃えた
@onready var TRAVEL_TIME: float = Settings.note_travel_time * 1000.0

@onready var conductor      = get_node("/root/Game/Conductor")
@onready var head: Sprite2D = $Head
@onready var body: Sprite2D = $Body
@onready var fx : GPUParticles2D = $HoldFX

var _holding          := false   # 押下中フラグ
var _head_judged      := false   # ヘッド判定済み
var _press_diff_ms    := 0.0     # Great / Good 判定用
var _result_on_release: String   # 「Great/Good/Miss」決定後に emit
const MISS_HEAD_GRACE_MS := 50      # 初期判定の猶予

#------------------------------------------------------------
func _ready() -> void:
	# ----- 見た目をセット ---------------------------------
	# 同じテクスチャを貼ってグラデを一体化
	head.texture = Note.TEX_NORMAL
	body.texture = Note.TEX_NORMAL
	head.centered = true
	body.centered = true  # 原点(0,0)が左上になる →Trueに変えた
	body.position.x = 0      # 念のためリセット

	# ボディの長さを duration に合わせてスケール
	var h_tex = head.texture.get_height()
	var pixel_per_ms = float(Settings.judge_line_y - SPAWN_Y) / TRAVEL_TIME
	var body_height  = max(1, int(duration_ms * pixel_per_ms))
	body.scale = Vector2(1, body_height / float(h_tex))
	body.position.y = h_tex / 2.0          # ヘッドにつなげる

	# 初期位置
	position.y = SPAWN_Y
	fx.emitting = false

	position = Vector2(position.x, SPAWN_Y)   # ← X は NoteSpawner が設定済み
	fx.emitting = false
	
	modulate.a = 0.0          # 初期 α = 0 （完全透明）
	visible    = true         # シーン側で非表示にしない

#------------------------------------------------------------
func _process(delta: float) -> void:
	# ◆ 落下アニメ
	var now = conductor.get_time_ms()
	var ratio = clamp((now - (hit_time_ms - TRAVEL_TIME)) / TRAVEL_TIME, 0, 1)
	position.y = lerp(SPAWN_Y, Settings.judge_line_y, ratio)

	# ◆ ヘッド判定猶予切れ
	if not _head_judged and now - hit_time_ms > 120:
		_finish("Miss")  # 押されないまま通過

	# ◆ ホールド中：離したら失敗
	if _holding and not _is_lane_pressed():
		_finish("Miss")

	# ◆ 終点に到達
	if _holding and now >= hit_time_ms + duration_ms:
		_finish(_result_on_release)
	
	if not _head_judged and now - hit_time_ms > MISS_HEAD_GRACE_MS:
		_finish("Miss", true)   # result = "Miss", early = true

	# 1) 落下距離を求める
	var traveled: float = position.y - SPAWN_Y          # 0 → 落下距離(px)

	# 2) 120px 落ちるまでに α を 0→1 へ
	const FADE_DIST = 120.0
	modulate.a = clamp(traveled / FADE_DIST, 0.0, 1.0)
	


#------------------------------------------------------------
func try_hit() -> void:
	# 1 回しか反応しない
	if _head_judged:
		return

	var diff = abs(conductor.get_time_ms() - hit_time_ms)
	if diff <= 50:
		_start_hold("Great")
	elif diff <= 100:
		_start_hold("Good")
# ──────────────────────────────────────────────
#  Miss エフェクト（通常ノーツと同じ）
# ──────────────────────────────────────────────
func _miss_effect() -> void:
	var tw := create_tween()

	# ノート全体をグレーに
	modulate = Color.WHITE         # 念のためリセット
	tw.tween_property(self, "modulate",
		Color(0.5, 0.5, 0.5, 1.0), 0.05)

	# 少し下＋左右ランダム 8px 落とす
	var target_pos := position + Vector2(randi_range(-8, 8), 60)
	tw.tween_property(self, "position", target_pos, 0.35)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# フェードアウト
	tw.tween_property(self, "modulate:a", 0.0, 0.35)

	tw.tween_callback(queue_free)


#------------------------------------------------------------
# 内部処理
#------------------------------------------------------------
func _start_hold(result_head: String) -> void:
	_head_judged       = true        # 以後 _try_hit させない
	_press_diff_ms = int(result_head != "Great")
	_result_on_release = result_head
	_holding           = true
	fx.emitting        = true        # パーティクル開始
	head.visible       = false       # ヘッドだけ消す

func _finish(result: String, early: bool = false) -> void:
	if judged:
		return

	judged      = true
	_holding    = false
	fx.emitting = false

	# スコア処理などは先に通知
	get_parent().emit_signal("note_judged", result, lane)

	if result == "Miss":
		_miss_effect()          # ← ★ここで演出をスタート
	else:
		visible = false         # Great / Good は即非表示
		queue_free()            # ← ★Miss では呼ばない


#------------------------------------------------------------
func _is_lane_pressed() -> bool:
	match lane:
		0:         return Input.is_action_pressed("lane0")
		1:         return Input.is_action_pressed("lane1")
		2:         return Input.is_action_pressed("lane2")
		3:         return Input.is_action_pressed("lane3")
		"special": return Input.is_action_pressed("special")
		_:         return false
