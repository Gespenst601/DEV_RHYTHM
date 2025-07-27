@tool
extends Node2D

#======================
# ▼ 見た目のパラメータ
#======================
@export var fill_color        : Color = Color("#222a")
@export var border_color      : Color = Color("#ffffff")
@export var border_width      : float = 3.0
@export var height_above_line : float = 1_000.0

@export var flash_color  : Color = Color("#ffffff")
@export var flash_time   : float = 0.25      # 完全消灯までの秒数
@export var flash_alpha  : float = 0.8       # 最大アルファ

#――― パルス（ゆらぎ）―――
@export var pulse_min_alpha : float = 0.20   # 背景アルファの下限
@export var pulse_max_alpha : float = 0.50   # 背景アルファの上限
@export var pulse_speed     : float = 1.0    # 周波数 (Hz)

#======================
# ▼ Settings が無い時の予備値（エディタ用）
#======================
@export var fallback_center_x   : float = 960.0
@export var fallback_lane_space : float = 200.0
@export var fallback_judge_y    : float = 880.0

#======================
# ▼ ワーク変数
#======================
var flash_intensity := [0.0, 0.0, 0.0, 0.0]  # 各レーンのフラッシュ強度
var pulse_time      : float = 0.0            # パルスタイマー
var pulse_tween: Tween

@onready var settings := get_node_or_null("/root/Settings")

#------------------------------------------------------------
# public API
#------------------------------------------------------------
func flash(lane: int, strength := 1.0) -> void:
	if lane >= 0 and lane < flash_intensity.size():
		flash_intensity[lane] = strength
		queue_redraw()

func flash_wide(strength := 1.0) -> void:
	for i in range(flash_intensity.size()):
		flash_intensity[i] = strength
	queue_redraw()

#------------------------------------------------------------
# lifecycle
#------------------------------------------------------------
func _ready() -> void:
	# もし前の Tween が残っていれば止める
	if pulse_tween:
		pulse_tween.kill()

	# 新しい Tween を作成してプロパティをアニメート
	pulse_tween = create_tween()
	pulse_tween.tween_property(self, "modulate:a", pulse_max_alpha, 1.0)
	pulse_tween.set_trans(Tween.TRANS_SINE)
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.set_loops()  # Ping-pong 無限ループ

func _process(delta: float) -> void:
	pulse_time += delta

	# フラッシュ減衰
	var need_redraw := false
	for i in range(flash_intensity.size()):
		if flash_intensity[i] > 0.0:
			flash_intensity[i] = max(0.0, flash_intensity[i] - delta/flash_time)
			need_redraw = true

	# パルスは毎フレーム描画
	need_redraw = true

	if need_redraw:
		queue_redraw()

func _draw() -> void:
	#--------- Settings 取得に失敗したら安全に抜ける ---------
	if settings == null:
		# エディタでは fallback 値で描画
		_draw_lanes(
			fallback_center_x,
			fallback_lane_space,
			fallback_judge_y
		)
		return

	# ランタイムは Settings の値で描画
	_draw_lanes(
		settings.center_x,
		settings.lane_spacing,
		settings.judge_line_y
	)

#------------------------------------------------------------
# 内部ヘルパー
#------------------------------------------------------------
func _draw_lanes(cx: float, lane_space: float, judge_y: float) -> void:
	var start_x = cx - 1.5 * lane_space
	var top     = judge_y - height_above_line
	var bottom  = judge_y
	var h       = bottom - top

	# パルス計算
	var phase         = pulse_time * pulse_speed * TAU
	var pulse_factor  = (sin(phase) + 1.0) * 0.5     # 0〜1
	var current_alpha = lerp(pulse_min_alpha, pulse_max_alpha, pulse_factor)

	for i in range(4):
		var left = start_x + i * lane_space - lane_space * 0.5
		var rect = Rect2(Vector2(left, top), Vector2(lane_space, h))

		# 背景（パルス）
		var c_fill = fill_color
		c_fill.a = current_alpha
		draw_rect(rect, c_fill)

		# 枠線
		draw_rect(rect, border_color, false, border_width)

		# フラッシュ
		if flash_intensity[i] > 0.0:
			var c_flash = flash_color
			c_flash.a = flash_alpha * flash_intensity[i]
			draw_rect(rect, c_flash)
