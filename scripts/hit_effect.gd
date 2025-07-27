# res://effects/HitEffect.gd
extends Node2D

@export var intensity: float = 1.0             # 1.0 = Great, 0.6 = Good など

@onready var particles: GPUParticles2D = $GPUParticles2D

func _ready() -> void:
	var mat := particles.process_material as ParticleProcessMaterial
	if mat:
		# ---- 初速を倍率掛け ----------------------------------
		# Godot4 の initial_velocity は Vector2(min, max)
		var v := mat.initial_velocity                       # ← Vector2
		v *= intensity                                      # 両成分に倍率を掛ける
		mat.initial_velocity = v
		# ---- 粒子数も調整 ------------------------------------
		particles.amount = int(particles.amount * intensity)
	# ---------------------------------------------------------
	particles.restart()                                     # emit!
	await get_tree().create_timer(particles.lifetime).timeout
	queue_free()                                            # 自壊
