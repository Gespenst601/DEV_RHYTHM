extends Node2D

func _ready() -> void:
	var start_x = Settings.center_x - 1.5 * Settings.lane_spacing
	for i in 4:
		var lane_sprite := get_node("Lane%d" % i)
		lane_sprite.position = Vector2(
			start_x + i * Settings.lane_spacing,
			Settings.judge_line_y   # 判定ラインと揃えたければ中心か下端に調整
		)
