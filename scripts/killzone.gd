extends Area2D

@onready var timer: Timer = $Timer


func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body.is_in_group("player"):
		print("Player entered killzone!")
		if body.has_method("initiate_death"):
			body.initiate_death()
	
func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "Destroyed":
		queue_free()
