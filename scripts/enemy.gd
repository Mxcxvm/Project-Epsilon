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

@export var sync_hp := 100:
	set(value):
		sync_hp = value
		if not is_multiplayer_authority(): 
			hp = value

@export var sync_animation := "":
	set(value):
		sync_animation = value
		if not is_multiplayer_authority():
			$AnimatedSprite2D.play(value)

@export var sync_damage := 5:
	set(value):
		sync_damage = value
		if not is_multiplayer_authority(): 
			damage = value

var hp = 30
const SPEED = 50
const GRAVITY = 980
var chase = false
var direction
var player
var damage = 5
	
func _enter_tree():
	# Only server should control enemies
	set_multiplayer_authority(1)  # Server controls all enemies
	print("[Enemy] Entering tree, authority: ", get_multiplayer_authority())
	
	sync_damage = damage
	
	# Configure spawner if available
	if multiplayer_spawner:
		multiplayer_spawner.despawned.connect(_on_despawned)

func _on_despawned():
	# Cleanup when despawned
	if multiplayer.is_server():
		queue_free()

func _ready():
	# Initialize sync properties
	sync_position = position
	sync_velocity = velocity
	sync_hp = hp
	sync_animation = ""
	sync_damage = damage
	
	set_physics_process(is_multiplayer_authority())
	
	$AnimatedSprite2D.play("Idle")
	
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
		
	# Wenn kein hp dann sterben
	if hp <= 0:
		$HitBox2D/HitBoxCollision2D.disabled = true
		chase = false
		$AnimatedSprite2D.play("Destroyed")
	
	velocity.y += GRAVITY * delta
	
	# Auf den boden bewegen
	if chase:
		direction = sign(player.position.x - position.x)
		velocity.x = direction * SPEED
	else:
		velocity.x = 0 
		
	move_and_slide()
		
	# Update sync variables at the end of physics processing
	sync_position = position
	sync_velocity = velocity
	sync_hp = hp
	
# Wenn der Player die Detection Area betritt --> chase player = true
func _on_detection_area_body_entered(body: Node2D) -> void:
	if not is_multiplayer_authority(): return
	if is_value_in_array(MultiplayerManager.connected_players, body.name):
		player = body
		chase = true

# Wenn der Player die Detection Area verlässt --> chase player = false
func _on_detection_area_body_exited(body: Node2D) -> void:
	if not is_multiplayer_authority(): return
	if is_value_in_array(MultiplayerManager.connected_players, body.name):
		player = null
		chase = false

# Nach der Destroy animation enemy verschwinden lassen
func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "Destroyed":
		queue_free()
		

# server only function for dealing damage to enemies
func apply_damage(damage_amount: int):
	if not multiplayer.is_server():
		return
	
	hp -= damage_amount
	sync_hp = hp
	
	print("Enemy took damage: ", damage_amount)
	print("Remaining enemy HP: ", hp)
	
	if hp <= 0:
		sync_animation = "Destroyed"
		call_deferred("disable_hitbox")
		chase = false

func disable_hitbox():
	$HitBox2D/HitBoxCollision2D.disabled = true

# client requests to apply damage to enemies
@rpc("any_peer", "reliable")
func request_apply_damage(damage_amount: int, attacker_id: int):
	if not multiplayer.is_server():
		return
	print("Damage request received from peer: ", attacker_id, " amount: ", damage_amount)
	apply_damage(damage_amount)

# Wenn die Hitbox was trifft und es sich um die Gruppe schwer hält --> verliere hp
func _on_hit_box_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("Sword"):
		var attacking_player = area.get_parent()
		if attacking_player and attacking_player.has_method("get_current_damage"):
			damage = attacking_player.get_current_damage()
			print("Enemy received attack with damage: ", damage, " from player: ", attacking_player.name)
			if multiplayer.is_server():
				if damage > 0:
					apply_damage(damage)
			else:
				# If client, request server to apply damage
				request_apply_damage.rpc_id(1, damage, multiplayer.get_unique_id())

func _on_hit_box_2d_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
		
	if body.name.is_valid_int():  # Check if it's a player
		if body.has_method("knockback"):
			var x = body.position.x - position.x
			var peer_id = body.name.to_int()
			
			# If its the host player apply knockback directly
			if peer_id == 1:
				body.knockback(500 if x > 0 else -500, damage)
			else:
				# For clients use RPC
				body.knockback.rpc_id(peer_id, 500 if x > 0 else -500, damage)

func is_value_in_array(array: Array, value) -> bool:
	for item in array:
		if str(item) == str(value):
			return true
	return false
