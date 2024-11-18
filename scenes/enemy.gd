extends Area2D

var hp = 100
var dead = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if dead == false:
		$AnimatedSprite2D.play("Idle")


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("Sword"):
		dead = true
		$AnimatedSprite2D.play("Destroyed")
			
			

func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "Destroyed":
		queue_free()
