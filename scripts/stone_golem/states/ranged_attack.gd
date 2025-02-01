extends State

const DETECTION_RANGE = 1300
const FOLLOW_RANGE = 300
const SPAWN_OFFSET = Vector2(40, -32)

var missile_scene = preload("res://scenes/Missile.tscn")

func enter():
	super.enter()
	if not owner.is_multiplayer_authority():
		return
		
	if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
		animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	owner.sync_animation = "ranged_attack"
	animation_player.play("ranged_attack")

func exit():
	super.exit()
	if owner.is_multiplayer_authority() and animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_player_animation_finished)

func _physics_process(_delta):
	super._physics_process(_delta)
	if not owner.is_multiplayer_authority():
		return
		
	if owner.player == null:
		owner.change_state("Idle")
		return
		
	var distance = owner.global_position.distance_to(owner.player.global_position)
	if distance > DETECTION_RANGE:
		owner.change_state("Idle")
	elif distance < FOLLOW_RANGE:
		owner.change_state("Follow")

func _on_animation_player_animation_finished(anim_name: String):
	if not owner.is_multiplayer_authority():
		return
		
	if anim_name == "ranged_attack":
		_spawn_projectile()
		animation_player.play("ranged_attack")

func _spawn_projectile():
	if not owner.player or not missile_scene or not owner.is_multiplayer_authority():
		return
		
	var game_node = owner.get_tree().current_scene
	if not game_node or not game_node.has_node("Missiles"):
		push_error("Failed to find Game node or Missiles container")
		return
		
	# calculate spawn position offset
	var spawn_offset = SPAWN_OFFSET 
	if owner.sprite.flip_h:
		spawn_offset.x = -spawn_offset.x  # flip offset when facing left
	
	var spawn_pos = owner.global_position + spawn_offset
	
	# initial direction based on direction the golem is facing
	var spawn_direction = owner.direction.normalized()
	
	# create missile with multiplayerspawner
	var missile = missile_scene.instantiate()
	missile.position = spawn_pos
	missile.initial_direction = spawn_direction
	missile.current_direction = spawn_direction
	missile.target = owner.player
	
	# rotation based on direction
	missile.rotation = spawn_direction.angle()
	missile.sync_rotation = spawn_direction.angle()
	
	# add missile to container
	var missiles_container = game_node.get_node("Missiles")
	missiles_container.add_child(missile, true)
	
	# target ID for synchronization
	if is_instance_valid(owner.player):
		missile.sync_target_id = int(str(owner.player.name))
