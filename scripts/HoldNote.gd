extends Node2D
class_name HoldNote
signal note_judged(result: String, lane)

@export var duration_ms: float = 0.0
var hit_time_ms: float          # ヘッドの判定時刻
var spawn_time_ms: float        # 実際のスポーン時刻（計算で求める）
var lane := 0
var judged := false

const SPAWN_Y := -100.0
@onready var TRAVEL_TIME: float = Settings.note_travel_time * 1000.0

@onready var conductor = get_node("/root/Game/Conductor")
@onready var head_note: Sprite2D = $HeadNote
@onready var hold_bar: Sprite2D = $HoldBar
@onready var tail_note: Sprite2D = $TailNote
@onready var fx: GPUParticles2D = $HoldFX

# ホールド状態
var _holding := false
var _head_judged := false
var _head_result := ""

# 判定時間
const GREAT_WINDOW_MS := 50.0
const GOOD_WINDOW_MS := 100.0
const MISS_GRACE_MS := 120.0

func _ready() -> void:
	# ★重要★ スポーン時刻を逆算
	_calculate_spawn_timing()
	
	_setup_visual_components()
	_calculate_positions()
	
	# 初期設定
	position.y = SPAWN_Y
	fx.emitting = false
	modulate.a = 0.0
	
	print("HoldNote - Hit time: %.1f, Spawn time: %.1f, Duration: %.1f" % [hit_time_ms, spawn_time_ms, duration_ms])

func _calculate_spawn_timing() -> void:
	# ホールドノーツのテール（終点）が判定ラインに到達する時刻
	var tail_hit_time = hit_time_ms + duration_ms
	
	# テールが判定ラインに到達するために必要なスポーン時刻
	spawn_time_ms = tail_hit_time - TRAVEL_TIME
	
	# デバッグ用
	var head_spawn_time = hit_time_ms - TRAVEL_TIME
	print("  Head should spawn at: %.1f, Tail should spawn at: %.1f" % [head_spawn_time, spawn_time_ms])

func _setup_visual_components() -> void:
	# ヘッドノーツ（通常ノーツと同じ）
	head_note.texture = Note.TEX_NORMAL
	head_note.centered = true
	head_note.position = Vector2.ZERO
	
	# ホールドバー（細長い）
	hold_bar.texture = _create_hold_bar_texture()
	hold_bar.centered = true
	
	# テールノーツ（ヘッドより小さめ）
	tail_note.texture = Note.TEX_NORMAL
	tail_note.centered = true
	tail_note.scale = Vector2(0.8, 0.8)
	tail_note.modulate = Color(1, 1, 1, 0.7)

func _calculate_positions() -> void:
	# ★修正版★ ホールドの長さをピクセルで計算
	var pixel_per_ms = float(Settings.judge_line_y - SPAWN_Y) / TRAVEL_TIME
	var bar_length_pixels = duration_ms * pixel_per_ms
	
	# ヘッドノーツは時間差分だけ下にオフセット
	var time_offset = hit_time_ms - spawn_time_ms  # 正の値になる
	var head_offset_pixels = time_offset * pixel_per_ms
	head_note.position.y = head_offset_pixels
	
	# バーはヘッドから下に伸ばす
	hold_bar.position.y = head_offset_pixels + bar_length_pixels / 2.0
	hold_bar.scale.y = bar_length_pixels / hold_bar.texture.get_height()
	
	# テールはバーの終端
	tail_note.position.y = head_offset_pixels + bar_length_pixels
	
	print("  Bar length: %.1f px, Head offset: %.1f px" % [bar_length_pixels, head_offset_pixels])

func _create_hold_bar_texture() -> Texture2D:
	var width = 12
	var height = 100
	
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	for y in range(height):
		var alpha_factor = 1.0 - (float(y) / height) * 0.3
		for x in range(width):
			var border = (x < 1 or x >= width - 1)
			var color: Color
			
			if border:
				color = Color(0.8, 0.9, 1.0, alpha_factor)
			else:
				color = Color(0.4, 0.6, 0.9, alpha_factor * 0.6)
			
			img.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	if judged:
		return

	var now = conductor.get_time_ms()
	
	# ★修正版★落下アニメーション - spawn_time_msを基準にする
	var ratio = clamp((now - spawn_time_ms) / TRAVEL_TIME, 0, 1)
	position.y = lerp(SPAWN_Y, Settings.judge_line_y, ratio)
	
	# フェードイン
	var traveled = position.y - SPAWN_Y
	modulate.a = clamp(traveled / 120.0, 0.0, 1.0)

	# 判定処理（hit_time_msを基準）
	if not _head_judged:
		_check_head_judgment(now)
	elif _holding:
		_check_hold_state(now)

func _check_head_judgment(now: float) -> void:
	var time_diff = now - hit_time_ms  # ヘッドの判定時刻との差
	
	if time_diff > MISS_GRACE_MS:
		_judge_head("Miss")
		return
	
	if _is_lane_pressed() and time_diff >= -MISS_GRACE_MS:
		var abs_diff = abs(time_diff)
		if abs_diff <= GREAT_WINDOW_MS:
			_judge_head("Great")
		elif abs_diff <= GOOD_WINDOW_MS:
			_judge_head("Good")

func _check_hold_state(now: float) -> void:
	# ホールド終了（テールの判定時刻）
	if now >= hit_time_ms + duration_ms:
		_finish_hold()
		return
	
	# キーリリース
	if not _is_lane_pressed():
		_judge_head("Miss")

func _judge_head(result: String) -> void:
	if _head_judged:
		return
		
	_head_judged = true
	_head_result = result
	
	print("Head judged: ", result, " at ", conductor.get_time_ms(), " (target: ", hit_time_ms, ")")
	
	if result == "Miss":
		_finish_with_result("Miss")
	else:
		_start_holding()

func _start_holding() -> void:
	_holding = true
	fx.emitting = true
	
	# ヘッドノーツを少し暗くして「消化済み」を表現
	head_note.modulate = Color(0.6, 0.6, 0.6, 1.0)
	
	# バーを光らせる
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(hold_bar, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.3)
	tween.tween_property(hold_bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

func _finish_hold() -> void:
	print("Hold finished: ", _head_result, " at ", conductor.get_time_ms())
	_finish_with_result(_head_result)

func _finish_with_result(result: String) -> void:
	if judged:
		return
		
	judged = true
	_holding = false
	fx.emitting = false
	
	note_judged.emit(result, lane)
	
	if result == "Miss":
		_miss_effect()
	else:
		queue_free()

func try_hit() -> void:
	if _head_judged:
		return
		
	var now = conductor.get_time_ms()
	var time_diff = abs(now - hit_time_ms)
	
	if time_diff <= GREAT_WINDOW_MS:
		_judge_head("Great")
	elif time_diff <= GOOD_WINDOW_MS:
		_judge_head("Good")

func _miss_effect() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(0.5, 0.5, 0.5, 1.0), 0.05)
	var target_pos := position + Vector2(randi_range(-8, 8), 60)
	tw.tween_property(self, "position", target_pos, 0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)

func _is_lane_pressed() -> bool:
	match lane:
		0: return Input.is_action_pressed("lane0")
		1: return Input.is_action_pressed("lane1")
		2: return Input.is_action_pressed("lane2")
		3: return Input.is_action_pressed("lane3")
		"special": return Input.is_action_pressed("special")
		_: return false
