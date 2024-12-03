extends CharacterBody2D

var hp = 30
const SPEED = 30
var chase = false
var direction
var player
var damage = 60
	
		
func _physics_process(delta: float) -> void:
	# Wenn kein hp dann sterben
	if hp <= 0:
		$HitBox2D/HitBoxCollision2D.disabled = true
		chase = false
		$AnimatedSprite2D.play("Destroyed")
	
	# Auf den boden bewegen
	if chase:
		var direction = sign(player.position.x - position.x)
		velocity.x = direction * SPEED
		move_and_slide()
	
# Wenn der Player die Detection Area betritt --> chase player = true
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player = body
		chase = true
		
# Wenn der Player die Detection Area verlässt --> chase player = false
func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player = null
		chase = false

# Nach der Destroy animation enemy verschwinden lassen
func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "Destroyed":
		queue_free()	
		
# Wenn die Hitbox was trifft und es sich um die Gruppe schwer hält --> verliere hp
func _on_hit_box_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("Sword"):
		var damage = player.get_current_damage()
		hp -= damage
		print("Damage dealt to enemy: ", damage)
		print("Remaining enemy HP: ", hp)


func _on_hit_box_2d_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player = body
		var x = player.position.x - position.x
		if x > 0:
			player.knockback(500, damage)
		else: 
			player.knockback(-500, damage)
		
