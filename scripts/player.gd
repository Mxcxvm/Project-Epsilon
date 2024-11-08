extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -300.0
var is_attacking = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Get the input direction -1, 0, 1
	var direction := Input.get_axis("move_left", "move_right")
	
	# Flip the Sprite
	if direction > 0:
		animated_sprite.flip_h = false	
	if direction < 0:
		animated_sprite.flip_h = true	
		
	# Play movement animations
	if is_on_floor():
		if direction == 0 and is_attacking == false:
			animated_sprite.play("idle")
		if direction != 0 and is_attacking == false:
			animated_sprite.play("run")
	elif !is_on_floor() and is_attacking == false:
		animated_sprite.play("jump")

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
	# Handle attacks
	if Input.is_action_just_pressed("attack"):
		animated_sprite.play("slash")
		is_attacking = true
		
	if Input.is_action_just_pressed("heavy_attack"):
		animated_sprite.play("heavy_attack")
		is_attacking = true

	move_and_slide()
	


func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "slash" or animated_sprite.animation == "heavy_attack":
		is_attacking = false
