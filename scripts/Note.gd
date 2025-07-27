extends Node2D
class_name Note
@export var note_type: String = "normal"  # "normal"/"wide"
signal note_judged(result, lane)   # ←★ここを追加★
static var SFX_NORMAL := preload("res://audio/SE/hit_normal.ogg")
static var SFX_WIDE   := preload("res://audio/SE/hit_wide.ogg")
@onready var sfx_player: AudioStreamPlayer2D = $HitPlayer
# ──────────────────────────────────────────────
# 自動テクスチャ付きノーツ
# ──────────────────────────────────────────────

@onready var conductor  = get_node("/root/Game/Conductor")
@onready var sprite: Sprite2D = $Sprite2D

var hit_time_ms: float
var lane                  # 0‑3  or "special"
#var note_type: String     # "normal"(既定) / "wide"
var judged := false

# 生成したテクスチャは static で1枚だけ保持
static var TEX_NORMAL: Texture2D
static var TEX_WIDE  : Texture2D
static var FX_SCENE := preload("res://effects/HitEffect.tscn")

func _spawn_hit_effect(result: String) -> void:
	# エフェクトシーンをインスタンス化
	var fx: Node2D = FX_SCENE.instantiate()
	# 追加先を NoteSpawner の親のさらに親配下にある "Effects" ノードへ
	var effects_layer = get_parent().get_parent().get_node("Effects")
	effects_layer.add_child(fx)
	# 位置を合わせる
	fx.global_position = global_position
	# Great なら 1.0、それ以外は 0.6 を代入
	fx.intensity = 1.0 if result == "Great" else 0.6


const SPAWN_Y: float = -100.0

func _ready() -> void:
	if TEX_NORMAL == null:
		_generate_textures()            # 最初の 1 度だけ呼ばれる
	sprite.texture = TEX_WIDE if note_type == "wide" else TEX_NORMAL
	sprite.centered = true
	position.y = SPAWN_Y
	
func _play_hit_sound(result: String) -> void:
	if result in ["Great", "Good"]:
		if note_type == "wide":
			sfx_player.stream = SFX_WIDE
		else:
			sfx_player.stream = SFX_NORMAL
		sfx_player.play()  # Miss は無音

func _process(delta: float) -> void:
	if judged:
		return
	var t_ms: float = Settings.note_travel_time * 1000.0
	var now: float  = conductor.get_time_ms()
	var ratio = clamp((now - (hit_time_ms - t_ms)) / t_ms, 0.0, 1.0)
	position.y = lerp(SPAWN_Y, Settings.judge_line_y, ratio)

	if now - hit_time_ms > 120.0:
		_judge("Miss")

func try_hit() -> void:
	var diff: float = abs(conductor.get_time_ms() - hit_time_ms)
	if diff <= 50.0:
		_judge("Great")
	elif diff <= 100.0:
		_judge("Good")
		
func _miss_effect() -> void:
	var tw := create_tween()
	
	# グレーに
	sprite.modulate = Color.WHITE   # 念のためリセット
	tw.tween_property(sprite, "modulate",
		Color(0.5, 0.5, 0.5, 1.0), 0.05)

	# Y 座標を少し下へ、ついでに X を±8px ランダムにずらすと“こぼれ落ちる”感が↑
	var target_pos := position + Vector2(randi_range(-8,8), 60)
	tw.tween_property(self, "position", target_pos, 0.35)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# フェードアウト
	tw.tween_property(sprite, "modulate:a", 0.0, 0.35)

	tw.tween_callback(queue_free)


# ──────────────────────────────────────────────
#  判定 & 親へ通知
# ──────────────────────────────────────────────
func _judge(result: String) -> void:
	_play_hit_sound(result)
	judged = true
	
	match result:
		"Miss":
			_miss_effect()
		_:   # Great / Good
			_spawn_hit_effect(result)
			visible = false
	
	get_parent().emit_signal("note_judged", result, lane)

# ──────────────────────────────────────────────
#  テクスチャ自動生成
# ──────────────────────────────────────────────
func _generate_textures() -> void:
	# 横グラデーション付きテクスチャを２種類作る
	TEX_NORMAL = _make_gradient_rect_tex(
		Color("#ff2244"),  # 左端の色
		Color("#ffcc66"),  # 右端の色
		176, 24
	)
	var wide_w = int(Settings.lane_spacing * 4)
	TEX_WIDE = _make_gradient_rect_tex(
		Color("#66ccff"),
		Color("#66ff66"),
		wide_w, 24
	)
	# ← ここで関数は終わり。}' は不要


func _make_gradient_rect_tex(col_start: Color, col_end: Color, w: int, h: int) -> Texture2D:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in range(w):
		var t = float(x) / float(w - 1)
		var col = col_start.lerp(col_end, t)
		for y in range(h):
			#var border = x < 2 or x >= w - 2 or y < 2 or y >= h - 2 #ここと
			#var pixel_color = Color.BLACK if border else col　#ここで枠線表示してる
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
	# ← ここも関数終わり。}' は不要
