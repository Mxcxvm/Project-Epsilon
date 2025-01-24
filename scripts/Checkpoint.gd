extends Area2D

var last_location = null
var is_activated = false

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_node("MultiplayerSynchronizer"):
		Checkpoint.last_location = body.global_position
		Checkpoint.is_activated = true
		animated_sprite_2d.play("touched")

func _on_animated_sprite_2d_animation_finished() -> void:
	if Checkpoint.is_activated:
		animated_sprite_2d.play("idle")
