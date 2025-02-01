extends Area2D

@onready var synchronizer := $MultiplayerSynchronizer as MultiplayerSynchronizer
@onready var sprite := $AnimatedSprite2D
@onready var sprite_offset := Vector2(20, 0)  # Adjust this value based on your sprite's offset

var target: Node2D = null
var speed = 200
var damage = 10
var max_lifetime = 8.0
var initial_direction := Vector2.ZERO
var turn_speed = 10
var current_direction := Vector2.ZERO

@export var sync_position := Vector2.ZERO:
	set(value):
		sync_position = value
		if not is_multiplayer_authority() and is_inside_tree():
			global_position = value

@export var sync_direction := Vector2.ZERO:
	set(value):
		sync_direction = value
		if is_inside_tree():
			current_direction = value

@export var sync_rotation := 0.0:
	set(value):
		sync_rotation = value
		if is_inside_tree():
			rotation = value

@export var sync_flip_h := false:
	set(value):
		sync_flip_h = value
		if sprite and is_inside_tree():
			sprite.flip_h = value

@export var sync_target_id := -1:
	set(value):
		sync_target_id = value
		if not is_inside_tree():
			await ready
			
		if value == -1:
			target = null
		else:
			# Look in both "player" and "players" groups to be safe
			var players = get_tree().get_nodes_in_group("player")
			players.append_array(get_tree().get_nodes_in_group("players"))
			for p in players:
				if str(p.name) == str(value):
					target = p
					break

@rpc("authority", "call_local", "reliable")
func despawn():
	queue_free()

func _ready():
	if not is_inside_tree():
		await tree_entered
		
	await get_tree().process_frame
	
	# initialize synchronizer
	if synchronizer == null:
		push_warning("MultiplayerSynchronizer not found, attempting to get it")
		synchronizer = get_node_or_null("MultiplayerSynchronizer")
		if synchronizer == null:
			push_error("Failed to find MultiplayerSynchronizer")
			return
		
	set_multiplayer_authority(1)
	
	if is_multiplayer_authority():
		get_tree().create_timer(max_lifetime).timeout.connect(func(): rpc("despawn"))
	
	# Set initial state if we're the authority
	if is_multiplayer_authority():
		sync_position = global_position
		if initial_direction != Vector2.ZERO:
			sync_direction = initial_direction
			current_direction = initial_direction
	
	# Set initial direction and sprite state
	if current_direction != Vector2.ZERO:
		sync_rotation = current_direction.angle()
	
	# Start animation
	if sprite:
		sprite.play("default")

func _physics_process(delta):
	if target and is_instance_valid(target):
		var target_direction = (target.position - position).normalized()
		
		if is_multiplayer_authority():
			# Gradually turn towards target
			current_direction = current_direction.lerp(target_direction, turn_speed * delta)
			current_direction = current_direction.normalized()
			
			# Update sync values
			sync_direction = current_direction
			
			# Update rotation to match movement direction
			sync_rotation = current_direction.angle()
	
	# Move in the current direction
	if is_multiplayer_authority():
		position += current_direction * speed * delta
		sync_position = position
	else:
		position += current_direction * speed * delta

func _on_body_entered(body):
	if not is_multiplayer_authority():
		return
		
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		rpc("despawn")
	elif not body.is_in_group("enemy"):
		# Destroy missile if it hits anything except enemies
		rpc("despawn")
