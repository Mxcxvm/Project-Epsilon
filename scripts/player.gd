extends CharacterBody2D

@export var multiplayer_spawner: MultiplayerSpawner
@onready var synchronizer := $MultiplayerSynchronizer as MultiplayerSynchronizer


# Sync variables
@export var sync_position := Vector2.ZERO:
	set(value):
		sync_position = value
		if not is_multiplayer_authority():
			position = value

@export var sync_velocity := Vector2.ZERO:
	set(value):
		sync_velocity = value
		if not is_multiplayer_authority():
			velocity = value

@export var sync_animation := "":
	set(value):
		sync_animation = value
		if not is_multiplayer_authority(): 
			$AnimatedSprite2D.play(value)

@export var sync_flip_h := false:
	set(value):
		sync_flip_h = value
		if not is_multiplayer_authority():
			$AnimatedSprite2D.flip_h = value


# Networking
@onready var player_hud := $PlayerHUD
@onready var inv := $Inventory

@onready var timer: Timer = $Timer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hud = $PlayerHUD
var death_timer: Timer

const max_health := 100
const max_stamina := 100.0

# Don't sync these directly
var current_health := max_health
var current_stamina := max_stamina
var is_dead := false


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
const HEAVY_ATTACK_MULTIPLIER = 4.0
var current_damage = 0

var is_attacking = false
var jump_count = 0
const MAX_JUMPS = 2
var is_dashing = false
var dash_timer = 0.0
var dash_direction = 0
var air_dash_used = false 
var is_charging = false
const CHARGE_ANIMATION_FRAME = 2


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	print("[Player] Entering tree, authority: ", get_multiplayer_authority())

func _ready() -> void:
	
	# set up initial values
	current_health = max_health
	current_stamina = max_stamina
	
	# initialize sync properties
	sync_position = position
	sync_velocity = velocity
	sync_animation = ""
	sync_flip_h = false
	
	animated_sprite = $AnimatedSprite2D
	if animated_sprite != null:
		animated_sprite.play("idle")
	
	# set up multiplayer authority
	if is_multiplayer_authority():
		if $Camera2D:
			$Camera2D.enabled = true
		# update HUD for this player
		if hud:
			hud.update_health(current_health)
			hud.update_stamina(current_stamina)
			stamina_value.emit(current_stamina)
	else:
		if $Camera2D:
			$Camera2D.enabled = false
	
	# make sure inventory is only controlled by its owner
	if inv:
		inv.set_multiplayer_authority(get_multiplayer_authority())
	
	# wait a bit for nodes to be ready
	await get_tree().create_timer(0.1).timeout
	
	# initial sync for all players
	if multiplayer.is_server():
		update_client_health.rpc(current_health, current_stamina)

	# only show HUD for the local player
	if hud and is_multiplayer_authority():
		hud.show()
	elif hud:
		hud.hide()
		
	

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	var direction := Input.get_axis("move_left", "move_right")

	if not is_on_floor() and not is_dashing:
		velocity += get_gravity() * delta
		
	if is_on_floor():
		air_dash_used = false
		jump_count = 0
	
	if is_attacking or is_dashing:
		direction = 0
	
	idle_and_move(direction)
	attack()
	dash(delta, direction)
	jump()
	move_and_slide()
	
	# Update sync variables at the end of physics processing
	sync_position = position
	sync_velocity = velocity
	if animated_sprite != null:
		if animated_sprite.animation != sync_animation:
			sync_animation = animated_sprite.animation
		if animated_sprite.flip_h != sync_flip_h:
			sync_flip_h = animated_sprite.flip_h

	if Input.is_action_pressed("jump") and not is_attacking and not is_dashing and current_stamina > 0:
		current_stamina = max(0, current_stamina - 25.0 * delta)
	elif current_stamina < max_stamina:
		current_stamina = min(max_stamina, current_stamina + STAMINA_REGEN * delta)
		update_hud_stamina()
		if not is_multiplayer_authority():
			request_health_update.rpc_id(1, current_health)
		else: 
			health_update(current_health, current_stamina)

# Handle Idle zu run und bewegung des charachters
func idle_and_move(direction):
	# Play movement animations
	if not is_dashing and not is_attacking:  # Keine Bewegungsanimationen während Dash/Attack
		if is_on_floor(): # Keine Bewegungsanimation während des Sprung
			if direction == 0:
				if animated_sprite != null:
					animated_sprite.play("idle")
			if direction != 0:
				if animated_sprite != null:
					animated_sprite.play("run")
	# Bewegung des Players
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
	# Flip the Sprite
	if direction > 0 and not is_attacking:
		if animated_sprite != null:
			animated_sprite.flip_h = false    
	if direction < 0 and not is_attacking:
		if animated_sprite != null:
			animated_sprite.flip_h = true

# Handle jump
func jump():
	# Bewegung des Players 
	if Input.is_action_just_pressed("jump") and is_dashing == false and is_attacking == false and jump_count < MAX_JUMPS:
		velocity.y = JUMP_VELOCITY
		jump_count += 1
		
		# Je nach count unterschiedliche Animation spielen
		if jump_count == 1:
			if animated_sprite != null:
				animated_sprite.play("jump")
		else:
			if animated_sprite != null:
				animated_sprite.play("jump_flip")

# Handle dash
func dash(delta: float, direction: float) -> void:
	# Dash kriterien
	if Input.is_action_just_pressed("dash") and not is_dashing and not is_attacking and current_stamina >= DASH_COST:
		# check ob air dash bereits verwendet wurde
		if not is_on_floor() and air_dash_used:
			return  # Verhindere den Dash

		# Dash Ausdauer Logik
		if air_dash_used == false:
			current_stamina -= DASH_COST
			is_dashing = true
			dash_timer = DASH_DURATION
			velocity.y = 0
			
			# Setze air_dash_used = True wenn wir in der Luft sind
			if not is_on_floor():
				air_dash_used = true
			
			# Dash-Richtung bestimmen
			if direction != 0:
				# Wenn Bewegungsrichtung aktiv, nutze diese für Dash
				dash_direction = direction
			else:
				# Andernfalls nutze Blickrichtung des Sprites
				if animated_sprite != null and animated_sprite.flip_h:
					dash_direction = -1  # Nach links
				else:
					dash_direction = 1   # Nach rechts
			
			# Sprite-Ausrichtung an Dash-Richtung anpassen
			if dash_direction < 0:
				if animated_sprite != null:
					animated_sprite.flip_h = true  # Nach links
			else:
				if animated_sprite != null:
					animated_sprite.flip_h = false  # Nach rechts
			# Dash-Animation abspielen
			if animated_sprite != null:
				animated_sprite.play("dash")
			
	# Dash Bewegungslogik 
	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction * DASH_SPEED
		velocity.y = 0
		$HitBox/HitBoxCollisionShape2D.disabled = true # Macht den Player während des Dash unverwundbar
		if dash_timer <= 0:
			is_dashing = false
			dash_timer = 0
	else:
		if not timer.time_left > 0: # Nur enable wenn der Unverwundbarkeits-Timer abgelaufen ist
			$HitBox/HitBoxCollisionShape2D.disabled = false

# Damage je nach attacke berechnen
func calculate_damage(attack_type: String) -> int:
	match attack_type:
		"light":
			return int(base_damage * LIGHT_ATTACK_MULTIPLIER)
		"heavy":
			return int(base_damage * HEAVY_ATTACK_MULTIPLIER)
		_:
			return 0

# Handle attack
func attack():
	if Input.is_action_just_pressed("light_attack") and current_stamina >= LIGHT_ATTACK_COST:
		current_stamina -= LIGHT_ATTACK_COST
		update_hud_stamina()
		if animated_sprite != null:
			animated_sprite.play("attack_light")
		is_attacking = true
		current_damage = calculate_damage("light")
		$AttackArea2D/CollisionShape2D.disabled = false
		if animated_sprite != null and animated_sprite.flip_h:
			animated_sprite.offset.x = -15 
			$AttackArea2D.position.x = 0
			$AttackArea2D.scale.x = -1
		else:
			animated_sprite.offset.x = 0
			$AttackArea2D.position.x = 0
			$AttackArea2D.scale.x = 1
		
		# Notify server about the attack
		if not multiplayer.is_server():
			notify_attack.rpc_id(1, current_damage)

	# Heavy Attack - Zwei Animationen
	if Input.is_action_pressed("heavy_attack") and not is_attacking and current_stamina >= HEAVY_ATTACK_COST:
		if not is_charging:
			is_charging = true
			is_attacking = true
			if animated_sprite != null:
				animated_sprite.play("attack_heavy_charge")
			if animated_sprite != null and animated_sprite.flip_h:
				animated_sprite.offset.x = -55 
				$AttackArea2D.position.x = 0
				$AttackArea2D.scale.x = -1
			else:
				animated_sprite.offset.x = 0
				$AttackArea2D.position.x = 0
				$AttackArea2D.scale.x = 1

	if Input.is_action_just_released("heavy_attack") and is_charging:
		current_stamina -= HEAVY_ATTACK_COST
		update_hud_stamina()
		if animated_sprite != null:
			animated_sprite.play("attack_heavy")
		current_damage = calculate_damage("heavy")
		$AttackArea2D/CollisionShape2D.disabled = false
		if animated_sprite != null and animated_sprite.flip_h:
			animated_sprite.offset.x = -55 
			$AttackArea2D.position.x = -0
			$AttackArea2D.scale.x = -1
		else:
			animated_sprite.offset.x = 0
			$AttackArea2D.position.x = 0
			$AttackArea2D.scale.x = 1
		is_charging = false

	if not is_attacking:
		if animated_sprite != null:
			animated_sprite.offset.x = 0
		$AttackArea2D.position.x = 0
		$AttackArea2D.scale.x = 1  # Reset der Kollisionsbox-Ausrichtung

# Handle attack Animations
func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite != null and (animated_sprite.animation == "attack_light" or animated_sprite.animation == "attack_heavy"):
		$AttackArea2D/CollisionShape2D.disabled = true
		is_attacking = false
		current_damage = 0  # Reset
		
	if animated_sprite != null and animated_sprite.animation == "death":
		print("u died")

# Client to server
@rpc("any_peer", "call_local")
func request_health_update(amount: int) -> void:
	if is_multiplayer_authority():
		current_health = clamp(current_health + amount, 0, max_health)
		if current_health <= 0:
			die()

func health_update(health: int, stamina: float) -> void:
	if not multiplayer.is_server():
		return
	
	if abs(stamina - current_stamina) > 5.0:  
		current_health = health
		current_stamina = stamina
		update_client_health.rpc(current_health, current_stamina)

# Server to clients
@rpc("any_peer", "reliable", "call_local")
func update_client_health(new_health: int, new_stamina: float) -> void:
	var old_health = current_health
	
	# Always update values on non-authority clients
	if not is_multiplayer_authority():
		if new_health != current_health:  # Only update if health changed
			current_health = new_health
			current_stamina = new_stamina
			
			print("[Player] Health updated from ", old_health, " to ", new_health,
				" - Peer ID: ", multiplayer.get_unique_id(),
				", Authority: ", get_multiplayer_authority())
			
			if player_hud:
				print("[Player] Updating player HUD with new health: ", new_health)
				player_hud.update_health(current_health)
				player_hud.update_stamina(current_stamina)
		return
	
	# For authority client, only update if values changed significantly
	if new_health != current_health or abs(new_stamina - current_stamina) > 5.0:
		current_health = new_health
		current_stamina = new_stamina
		
		print("[Player] Health updated from ", old_health, " to ", new_health,
			" - Peer ID: ", multiplayer.get_unique_id(),
			", Authority: ", get_multiplayer_authority())
		
		if player_hud:
			print("[Player] Updating player HUD with new health: ", new_health)
			player_hud.update_health(current_health)
			player_hud.update_stamina(current_stamina)

@rpc("any_peer", "reliable", "call_local")
func initiate_death() -> void:
	print("Initiating death sequence for player: ", name, " on peer: ", multiplayer.get_unique_id())
	
	# Disable all RPCs and physics first
	set_physics_process(false)
	set_process(false)
	
	# Make sure animation syncs across network
	if animated_sprite != null:
		sync_animation = "death"
		animated_sprite.play("death")
	
	# Create a timer to handle respawn after animation
	if death_timer:
		death_timer.queue_free()
	death_timer = Timer.new()
	death_timer.one_shot = true
	death_timer.wait_time = 2.0
	add_child(death_timer)
	death_timer.timeout.connect(_on_death_animation_finished)
	death_timer.start()

func _on_death_animation_finished() -> void:
	print("Death animation finished for player: ", name)
	if death_timer:
		death_timer.queue_free()
		death_timer = null
		
	# Only server initiates respawn
	if multiplayer.is_server():
		initiate_respawn.rpc()

@rpc("any_peer", "reliable", "call_local")
func initiate_respawn() -> void:
	print("Respawning player: ", name)
	# Reset player state
	current_health = max_health
	current_stamina = max_stamina
	is_dead = false
	
	if Checkpoint.is_activated and Checkpoint.last_location:
		position = Checkpoint.last_location
		
	else:
		# Fallback 
		position = Vector2(0, -60)

	sync_position = position
	velocity = Vector2.ZERO
	sync_velocity = velocity
	
	# Reset physics and animations
	set_physics_process(true)
	set_process(true)
	if $CollisionShape2D:
		$CollisionShape2D.set_deferred("disabled", false)
	if $HitBox/HitBoxCollisionShape2D:
		$HitBox/HitBoxCollisionShape2D.set_deferred("disabled", false)
	if animated_sprite:
		animated_sprite.visible = true
		sync_animation = "idle"
		animated_sprite.play("idle")
	
	# Update HUD
	if player_hud:
		player_hud.update_health(current_health)
		player_hud.update_stamina(current_stamina)
	if hud:
		hud.update_health(current_health)
		hud.update_stamina(current_stamina)
	stamina_value.emit(current_stamina)
	
	# Sync health and stamina to all clients
	if multiplayer.is_server():
		update_client_health.rpc(current_health, current_stamina)

func die() -> void:
	print("Die called with health: ", current_health, " on peer: ", multiplayer.get_unique_id())
	if multiplayer.is_server():
		# Server initiates death for everyone
		initiate_death.rpc()
	else:
		# Clients request death from server
		request_death.rpc_id(1)

@rpc("any_peer", "reliable")
func request_death() -> void:
	if multiplayer.is_server():
		print("Server received death request from peer: ", multiplayer.get_remote_sender_id())
		# Server validates and initiates death for everyone
		initiate_death.rpc()

# damage 
func take_damage(amount: int) -> void:
	print("Taking damage: ", amount, " current health: ", current_health)
	current_health -= amount
	if hud:
		hud.update_health(current_health)
		
	# Always sync health after taking damage
	if multiplayer.is_server():
		update_client_health.rpc(current_health, current_stamina)
		
	print("Health after damage: ", current_health, " on peer: ", multiplayer.get_unique_id())
	
	if current_health <= 0:
		die()
	else:
		animated_sprite.play("get_hit")

@rpc("any_peer", "reliable")
func request_damage(amount: int) -> void:
	print("Server received damage request: ", amount)
	if multiplayer.is_server():
		take_damage(amount)
		# Sync the new health to all clients
		update_client_health.rpc(current_health, current_stamina)

@rpc("any_peer", "reliable")
func notify_attack(damage_amount: int) -> void:
	print("Server received attack notification with damage: ", damage_amount)
	if multiplayer.is_server():
		current_damage = damage_amount

func update_hud_stamina() -> void:
	if player_hud:
		player_hud.update_stamina(current_stamina)
	if hud:
		hud.update_stamina(current_stamina)
	stamina_value.emit(current_stamina)


# Knockback und Schaden wenn der Player getroffen wird, macht den Player für 2 Sekunden unverwundbar
@rpc("any_peer", "reliable", "call_local")
func knockback(x, damage) -> void:
	print("Received knockback with damage: ", damage)
	if not $HitBox/HitBoxCollisionShape2D.disabled:
		call_deferred("_apply_knockback", x, damage)

func _apply_knockback(x, damage) -> void:
	print("Applying knockback and damage: ", damage)
	# Apply knockback locally
	velocity.x = x * 2
	velocity.y = -100
	
	# Handle damage
	if multiplayer.is_server():
		take_damage(damage)
		update_client_health.rpc(current_health, current_stamina)
	else:
		print("Requesting damage from server: ", damage)
		request_damage.rpc_id(1, damage)
	
	$HitBox/HitBoxCollisionShape2D.disabled = true
	timer.start()
	
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate:a", 0.5, 0)
	tween.tween_property(animated_sprite, "modulate:a", 1.0, 0)
	tween.set_loops(10)

# was 
func _on_timer_timeout() -> void:
	$HitBox/HitBoxCollisionShape2D.disabled = false
	if animated_sprite != null:
		animated_sprite.modulate.a = 1.0 # Stelle normale Sichtbarkeit wieder her

# Attack Damage rückgabe für den Enemy
func get_current_damage() -> int:
	return current_damage

@rpc("reliable", "call_local")
func request_item_pickup(pickup_node_path: NodePath) -> void:
	if multiplayer.is_server():
		var interactable = get_node_or_null(pickup_node_path)
		if not interactable or not interactable.is_in_group("pickup_items"):
			return

		var requesting_player = multiplayer.get_remote_sender_id()
		if requesting_player != multiplayer.get_unique_id():
			return

		process_item_pickup(pickup_node_path)
	else:
		rpc_id(1, "request_item_pickup", pickup_node_path)


@rpc("reliable", "call_local")
func process_item_pickup(pickup_node_path: NodePath) -> void:
	var interactable = get_node_or_null(pickup_node_path)
	if not interactable:
		return

	var item_data = interactable.get_item_data()
	if add_item_to_inventory(item_data):
		interactable.queue_free()

		rpc("sync_item_removal", pickup_node_path)
		
@rpc("reliable")
func sync_item_removal(pickup_node_path: NodePath) -> void:
	var interactable = get_node_or_null(pickup_node_path)
	if interactable:
		interactable.queue_free()

func _on_interact(interactable: Node2D) -> void:
	if not is_multiplayer_authority():
		return  

	if interactable.is_in_group("pickup_items"):
		request_item_pickup.rpc_id(1, interactable.get_path())


func add_item_to_inventory(item_data: ItemData) -> bool:
	var inventory = $Inventory
	if not inventory:
		print("Inventory node not found!")
		return false
		
	var inv_grid = inventory.get_node_or_null("%Inv")
	if not inv_grid:
		print("Inventory grid not found!")
		return false
	
	if not is_multiplayer_authority():
		return false
	
	for slot in inv_grid.get_children():
		if slot.get_child_count() == 0:
			var item = InventoryItem.new()
			item.init(item_data)
			slot.add_child(item)
			sync_inventory.rpc(slot.get_path(), item_data.resource_path)
			return true
	
	return false

@rpc("reliable", "call_local")
func sync_inventory(slot_path: NodePath, item_resource_path: String) -> void:
	if is_multiplayer_authority():
		return
		
	var slot = get_node_or_null(slot_path)
	if not slot:
		return
		
	var item = InventoryItem.new()
	item.init(load(item_resource_path))
	slot.add_child(item)
