extends Area2D

@onready var timer: Timer = $Timer

func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body.name == "Player":
		print("You Died!")
		timer.start()
	
func _on_timer_timeout():
	get_tree().reload_current_scene()

func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "Destroyed":
		queue_free()
