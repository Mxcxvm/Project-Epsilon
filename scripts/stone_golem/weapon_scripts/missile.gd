extends Area2D

@onready var synchronizer := $MultiplayerSynchronizer as MultiplayerSynchronizer
@onready var sprite := $AnimatedSprite2D
@onready var sprite_offset := Vector2(20, 0)  # offset für den spawnpunkt der raketen

var target: Node2D = null
var speed = 100
var damage = 10
var max_lifetime = 8.0
var initial_direction := Vector2.ZERO
var turn_speed = 7
var current_direction := Vector2.ZERO
var health = 1  # 1 hp, dass sie abgewehrt werden können

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
			var players = get_tree().get_nodes_in_group("player")
			players.append_array(get_tree().get_nodes_in_group("players"))
			for p in players:
				if str(p.name) == str(value):
					target = p
					break

@export var sync_health := 1:
	set(value):
		sync_health = value
		if not is_multiplayer_authority():
			health = value

@rpc("authority", "call_local", "reliable")
func despawn():
	# check ob anfrage von authority kommt oder ueber rpc die anfrage kommt
	if not (is_multiplayer_authority() or multiplayer.get_remote_sender_id() == 1):
		return
	queue_free()

@rpc("any_peer", "reliable")
func request_damage(amount: int) -> void:
	if not multiplayer.is_server():
		return
		
	handle_damage(amount)

func handle_damage(amount: int) -> void:
	if not multiplayer.is_server():
		return
		
	if amount <= 0:
		return
		
	health -= amount
	sync_health = health
	
	if health <= 0:
		if multiplayer.is_server():
			rpc("despawn")  # client despawn
			queue_free()  # local despawn

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
		get_tree().create_timer(max_lifetime).timeout.connect(func(): 
			queue_free()
			rpc("despawn")
		)
	
	if is_multiplayer_authority():
		sync_position = global_position
		sync_health = health
		if initial_direction != Vector2.ZERO:
			sync_direction = initial_direction
			current_direction = initial_direction
	
	if current_direction != Vector2.ZERO:
		sync_rotation = current_direction.angle()
	
	if sprite:
		sprite.play("default")

func _physics_process(delta):
	if target and is_instance_valid(target):
		var hitbox = target.get_node_or_null("HitBox")
		var target_pos = target.position
		
		if hitbox:
			target_pos = hitbox.global_position
			
		var target_direction = (target_pos - position).normalized()
		
		if is_multiplayer_authority():
			current_direction = current_direction.lerp(target_direction, turn_speed * delta)
			current_direction = current_direction.normalized()
			
			sync_direction = current_direction
			
			sync_rotation = current_direction.angle()
	
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
		queue_free()
		rpc("despawn")
	# despawn missile wenn etwas anderes als gegner gehittet werden
	elif not body.is_in_group("enemy"):
		queue_free()
		rpc("despawn")

func _on_area_entered(area: Area2D) -> void:
	
	if not area.is_in_group("player_attack"):
		return
		
	var player = area.get_parent()
	if player and player.has_method("get_current_damage"):
		var damage = player.get_current_damage()
		if damage > 0:
			if multiplayer.is_server():
				handle_damage(damage)
			else:
				request_damage.rpc_id(1, damage)
