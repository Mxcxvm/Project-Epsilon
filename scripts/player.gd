extends CharacterBody2D

@export var inv: Inv

# signals
signal stamina_value(current_stamina)

# Movement Konstanten
const SPEED = 125.0
const JUMP_VELOCITY = -250.0
const DASH_SPEED = 200.0
const DASH_DURATION = 0.4

# Stamina Konstanten
const MAX_STAMINA = 100.0
const STAMINA_REGEN = 25.0  
const DASH_COST = 25.0
const LIGHT_ATTACK_COST = 20.0
const HEAVY_ATTACK_COST = 35.0

# Damage Konstanten
var base_damage = 10
const LIGHT_ATTACK_MULTIPLIER = 1.0
const HEAVY_ATTACK_MULTIPLIER = 2.0
var current_damage = 0

var current_stamina = MAX_STAMINA
var is_attacking = false
var jump_count = 0
const MAX_JUMPS = 2
var is_dashing = false
var dash_timer = 0.0
var dash_direction = 0
var air_dash_used = false 
var is_charging = false
const CHARGE_ANIMATION_FRAME = 2

# Health System
var max_health = 100
var current_health = max_health

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	current_health = max_health
			
func _physics_process(delta: float) -> void:
	# signal des staminas
	emit_signal("stamina_value", current_stamina)
	
	# Regeneriere Stamina
	if not is_attacking and not is_dashing:
		current_stamina = min(current_stamina + STAMINA_REGEN * delta, MAX_STAMINA)
	
	# Get the input direction -1, 0, 1
	var direction := Input.get_axis("move_left", "move_right")

	# Apply Gravity, aber nicht im dash (Gerader Dash in der Luft)
	if not is_on_floor() and not is_dashing:
		velocity += get_gravity() * delta
		
	# Reset air dash und sprung wenn auf Boden
	if is_on_floor():
		air_dash_used = false
		jump_count = 0
	
	# Verhindere Bewegung während des Angriffs oder Dashs
	if is_attacking or is_dashing:
		direction = 0
	
	# Reihenfolge wichtig
	idle_and_move(direction)
	attack()
	dash(delta, direction)
	jump()
	move_and_slide()

# Handle Idle to run 
func idle_and_move(direction):
	# Play movement animations
	if not is_dashing and not is_attacking:  # Keine Bewegungsanimationen während Dash/Attack
		if is_on_floor(): # Keine Bewegungsanimation während des Sprung
			if direction == 0:
				animated_sprite.play("idle")
			if direction != 0:
				animated_sprite.play("run")
	# 
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
	# Flip the Sprite
	if direction > 0 and not is_attacking:
		animated_sprite.flip_h = false    
	if direction < 0 and not is_attacking:
		animated_sprite.flip_h = true

# Handle jump
func jump():
	if Input.is_action_just_pressed("jump") and is_dashing == false and is_attacking == false and jump_count < MAX_JUMPS:
		velocity.y = JUMP_VELOCITY
		jump_count += 1
		
		if jump_count == 1:
			animated_sprite.play("jump")
		else:
			animated_sprite.play("jump_flip")
			
#Handle dash
func dash(delta: float, direction: float) -> void:
	# Handle dash
	if Input.is_action_just_pressed("dash") and not is_dashing and not is_attacking and current_stamina >= DASH_COST:
		# check ob air dash bereits verwendet wurde
		if not is_on_floor() and air_dash_used:
			return  # Verhindere den Dash
			
		if air_dash_used == false:
			
			current_stamina -= DASH_COST
			is_dashing = true
			dash_timer = DASH_DURATION
			velocity.y = 0
			
			# Setze air_dash_used wenn wir in der Luft sind
			if not is_on_floor():
				air_dash_used = true
			
			# Dash-Richtung bestimmen
			if direction != 0:
				# Wenn Bewegungsrichtung aktiv, nutze diese für Dash
				dash_direction = direction
			else:
				# Andernfalls nutze Blickrichtung des Sprites
				if animated_sprite.flip_h:
					dash_direction = -1  # Nach links
				else:
					dash_direction = 1   # Nach rechts
					
			# Dash-Animation abspielen
			animated_sprite.play("dash")
			
			# Sprite-Ausrichtung an Dash-Richtung anpassen
			if dash_direction < 0:
				animated_sprite.flip_h = true  # Nach links
			else:
				animated_sprite.flip_h = false  # Nach rechts
	# Dash logik 
	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction * DASH_SPEED
		velocity.y = 0
		if dash_timer <= 0:
			is_dashing = false
			dash_timer = 0

# Damage je nach attacke berechnen
func calculate_damage(attack_type: String) -> int:
	match attack_type:
		"light":
			return int(base_damage * LIGHT_ATTACK_MULTIPLIER)
		"heavy":
			return int(base_damage * HEAVY_ATTACK_MULTIPLIER)
		_:
			return 0
			

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "attack_light" or animated_sprite.animation == "attack_heavy":
		$AttackArea2D/CollisionShape2D.disabled = true
		is_attacking = false
		current_damage = 0  # Reset
		
# Handle attack
func attack():
	if Input.is_action_just_pressed("light_attack") and current_stamina >= LIGHT_ATTACK_COST:
		current_stamina -= LIGHT_ATTACK_COST
		animated_sprite.play("attack_light")
		is_attacking = true
		current_damage = calculate_damage("light")
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
		current_damage = calculate_damage("heavy")
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

	if not is_attacking:
		animated_sprite.offset.x = 0
		$AttackArea2D.position.x = 0
		$AttackArea2D.scale.x = 1  # Reset der Kollisionsbox-Ausrichtung

# Schaden (Noch fertig machen)
func take_damage(amount: int) -> void:
	current_health -= amount
	# TODO Hier anstatt aufruf stattdessen signal anlegen
	%HUD.update_health(current_health)
	print("Player took ", amount, " damage. Remaining health: ", current_health)
	if current_health <= 0:
		die()

# Handle die
func die() -> void:
	print("Player died!")

func get_current_damage() -> int:
	return current_damage

func collect(item):
	inv.insert(item)
