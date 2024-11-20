extends CharacterBody2D

@export var inv: Inv

const SPEED = 125.0
const JUMP_VELOCITY = -250.0
const DASH_SPEED = 350.0
const DASH_DURATION = 0.3

# Stamina Konstanten
const MAX_STAMINA = 100.0
const STAMINA_REGEN = 25.0  
const DASH_COST = 25.0
const LIGHT_ATTACK_COST = 20.0
const HEAVY_ATTACK_COST = 35.0

var current_stamina = MAX_STAMINA
var is_attacking = false
var jump_count = 0
const MAX_JUMPS = 2
var is_dashing = false
var dash_timer = 0.0
var dash_direction = 0
var air_dash_used = false 
var is_charging = false  # Variable für den Charge-Status
const CHARGE_ANIMATION_FRAME = 2  # Der Frame, an dem die Charge-Animation stoppt

var damage = 0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	
	# Regeneriere Stamina
	if not is_attacking and not is_dashing:
		current_stamina = min(current_stamina + STAMINA_REGEN * delta, MAX_STAMINA)
	
	# Add the gravity only when not dashing
	if not is_on_floor() and not is_dashing:
		velocity += get_gravity() * delta
	
	# Reset air dash when touching floor
	if is_on_floor():
		air_dash_used = false
		jump_count = 0
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_attacking == false and jump_count < MAX_JUMPS:
		velocity.y = JUMP_VELOCITY
		jump_count += 1
		
		if jump_count == 1:
			animated_sprite.play("jump")
		else:
			animated_sprite.play("jump_flip")
	
	# Get the input direction -1, 0, 1
	var direction := Input.get_axis("move_left", "move_right")
	
	# Handle dash
	if Input.is_action_just_pressed("dash") and not is_dashing and not is_attacking and current_stamina >= DASH_COST:
		# check if air dash already used
		if not is_on_floor() and air_dash_used:
			return  # Verhindere den Dash
			
		current_stamina -= DASH_COST
		is_dashing = true
		dash_timer = DASH_DURATION
		velocity.y = 0
		
		# Setze air_dash_used wenn wir in der Luft sind
		if not is_on_floor():
			air_dash_used = true
			
		if direction != 0:
			dash_direction = direction
		else:
			dash_direction = -1 if animated_sprite.flip_h else 1
		animated_sprite.play("dash")
		if dash_direction < 0:
			animated_sprite.flip_h = true
		else:
			animated_sprite.flip_h = false
	
	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction * DASH_SPEED
		velocity.y = 0
		if dash_timer <= 0:
			is_dashing = false
			dash_timer = 0
	
	# Verhindere Bewegung während des Angriffs oder Dashs
	if is_attacking or is_dashing:
		direction = 0
	
	# Flip the Sprite
	if direction > 0 and not is_attacking:
		animated_sprite.flip_h = false    
	if direction < 0 and not is_attacking:
		animated_sprite.flip_h = true    
		
	# Play movement animations
	if not is_dashing and not is_attacking:  # Keine Bewegungsanimationen während Dash/Attack
		if is_on_floor():
			if direction == 0:
				animated_sprite.play("idle")
			if direction != 0:
				animated_sprite.play("run")
		elif not is_attacking and animated_sprite.animation != "jump" and animated_sprite.animation != "jump_flip":
			if jump_count == 1:
				animated_sprite.play("jump")
			elif jump_count == 2:
				animated_sprite.play("jump_flip")

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
	# Handle attacks
	if direction == 0:  # Nur wenn keine Bewegung stattfindet
		if Input.is_action_just_pressed("light_attack") and current_stamina >= LIGHT_ATTACK_COST:
			current_stamina -= LIGHT_ATTACK_COST
			animated_sprite.play("attack_light")
			is_attacking = true
			$AttackArea2D/CollisionShape2D.disabled = false
			if animated_sprite.flip_h:
				animated_sprite.offset.x = -15 
				$AttackArea2D.position.x = 0
				$AttackArea2D.scale.x = -1
			else:
				animated_sprite.offset.x = 0
				$AttackArea2D.position.x = 0
				$AttackArea2D.scale.x = 1

		# Heavy Attack - Zwei Animationen
		if Input.is_action_pressed("heavy_attack") and not is_attacking and current_stamina >= HEAVY_ATTACK_COST:
			if not is_charging:
				is_charging = true
				is_attacking = true
				animated_sprite.play("attack_heavy_charge")
				if animated_sprite.flip_h:
					animated_sprite.offset.x = -55 
					$AttackArea2D.position.x = -0
					$AttackArea2D.scale.x = -1
				else:
					animated_sprite.offset.x = 0
					$AttackArea2D.position.x = 0
					$AttackArea2D.scale.x = 1

		if Input.is_action_just_released("heavy_attack") and is_charging:
			current_stamina -= HEAVY_ATTACK_COST
			animated_sprite.play("attack_heavy")
			$AttackArea2D/CollisionShape2D.disabled = false
			if animated_sprite.flip_h:
				animated_sprite.offset.x = -55 
				$AttackArea2D.position.x = -0
				$AttackArea2D.scale.x = -1
			else:
				animated_sprite.offset.x = 0
				$AttackArea2D.position.x = 0
				$AttackArea2D.scale.x = 1
			is_charging = false

	# Optional: Abbruch des Charge
	if not Input.is_action_pressed("heavy_attack") and is_charging:
		is_charging = false
		is_attacking = false  # Reset auch den Attack-Status
		if not is_attacking:
			animated_sprite.play("idle")

	# Stelle sicher, dass der Offset zurückgesetzt wird, wenn kein Angriff stattfindet
	if not is_attacking:
		animated_sprite.offset.x = 0
		$AttackArea2D.position.x = 0
		$AttackArea2D.scale.x = 1  # Reset der Kollisionsbox-Ausrichtung

	move_and_slide()

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "attack_light" or animated_sprite.animation == "attack_heavy":
		$AttackArea2D/CollisionShape2D.disabled = true
		is_attacking = false
	elif animated_sprite.animation == "dash":
		is_dashing = false

func collect(item):
	inv.insert(item)
