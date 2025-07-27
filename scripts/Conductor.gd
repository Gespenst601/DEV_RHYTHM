extends Node
@export var player: AudioStreamPlayer
@export var manual_offset_ms := 0.0

func play() -> void:
	player.play()

func get_time_ms() -> float:
	return player.get_playback_position() * 1000.0 + manual_offset_ms
