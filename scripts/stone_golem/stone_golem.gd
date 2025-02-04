extends CharacterBody2D

const MAX_HEALTH = 1000
const CHECK_NEAREST_INTERVAL = 0.2

@export var MOVEMENT_SPEED: float = 100.0

@onready var synchronizer = $MultiplayerSynchronizer
@onready var sprite = $Sprite2D
@onready var progress_bar = $UI/ProgressBar
@onready var state_machine = $FiniteStateMachine
@onready var player_detection = $PlayerDetection
@onready var animation_player = $AnimationPlayer
@onready var cave_area = $CaveArea
@onready var block_cooldown_timer = Timer.new()
var block_on_cooldown : bool = false

var players = []
var player = null
var direction : Vector2 = Vector2.ZERO
var armor = 1
var player_in_range = false
var detected_bodies = []
var check_nearest_timer = 0.0
var player_damage = 0
var is_armor_buff_active = false

# sync variables
@export var sync_position := Vector2.ZERO:
	set(value):
		sync_position = value
		if not is_multiplayer_authority(): 
			position = value

@export var sync_direction := Vector2.ZERO:
	set(value):
		sync_direction = value
		if not is_multiplayer_authority():
			direction = value
			if sprite and direction != Vector2.ZERO:
				sprite.flip_h = direction.x < 0

@export var sync_target_player_id := -1:
	set(value):
		sync_target_player_id = value
		if not is_multiplayer_authority():
			if value == -1:
				player = null
			else:
				for p in players:
					if str(p.name) == str(value):
						player = p
						break

@export var sync_state := "":
	set(value):
		sync_state = value
		if not is_multiplayer_authority() and state_machine and value != "":
			state_machine.change_state(value)

@export var sync_animation := "":
	set(value):
		if value == sync_animation:
			return
		sync_animation = value
		if animation_player and value != "":
			# check if animation exists
			if animation_player.has_animation(value):
				animation_player.stop()
				animation_player.play(value)
				# reset laser sprite frame for Laser animation
				if value == "laser_cast":
					$Pivot/Sprite2D.frame = 0
				elif value == "Laser":
					$Pivot/Sprite2D.frame = 1

@export var sync_pivot_rotation : float = 0.0:
	set(value):
		sync_pivot_rotation = value
		if not is_multiplayer_authority():
			var pivot = get_node_or_null("Pivot")
			if pivot:
				$Pivot.rotation = value

@export var sync_progress_bar_visible := false:
	set(value):
		sync_progress_bar_visible = value
		if progress_bar:
			progress_bar.visible = value

@export var sync_health := MAX_HEALTH:
	set(value):
		sync_health = value
		if progress_bar:
			progress_bar.value = value

var health = MAX_HEALTH:
	set(value):
		var damage_taken = health - value
		
		# apply damage reduction if in block state
		if state_machine and state_machine.current_state.name == "Block":
			damage_taken *= state_machine.get_node("Block").DAMAGE_REDUCTION
			value = health - damage_taken
		
		health = value
		if progress_bar:
			progress_bar.value = value
			if value <= 0:
				progress_bar.visible = false
				if is_multiplayer_authority():
					sync_state = "Death"
					sync_animation = "death"
				state_machine.change_state("Death")
			else:
				if damage_taken > 0:
					print("[GOLEM] Took ", damage_taken, " damage. Health: ", value, "/", MAX_HEALTH)
				check_armor_buff()
				
				# update hit counter for block state
				if damage_taken > 0:  # only count actual hits
					if state_machine.current_state.name != "Dead":
						var block_state = state_machine.get_node("Block")
						block_state.on_hit()
						
						var current_hp_percent = float(health) / MAX_HEALTH
						if current_hp_percent <= block_state.HP_THRESHOLD_PERCENT and block_state.can_activate(self) and state_machine.current_state.name != "Block" and not block_on_cooldown:
							var previous_state = state_machine.current_state.name
							sync_state = "Block"
							sync_animation = "block"
							state_machine.change_state("Block")
							block_on_cooldown = true
							block_cooldown_timer.start()
							block_state.recent_hits = 0
							block_state.hit_timer = 0

func check_armor_buff():
	if not is_multiplayer_authority():
		return
		
	if is_armor_buff_active:
		return
		
	var armor_buff_state = state_machine.get_node("ArmorBuff")
	if armor_buff_state.should_activate(self):
		is_armor_buff_active = true
		var previous_state = state_machine.current_state.name
		sync_state = "ArmorBuff"
		sync_animation = "armor buff"
		state_machine.change_state("ArmorBuff")
		
		await get_tree().create_timer(1.0).timeout
		sync_state = previous_state
		sync_animation = ""
		state_machine.change_state(previous_state)
		is_armor_buff_active = false

func _enter_tree():
	set_multiplayer_authority(1)  # server controls enemies

func _ready():
	if progress_bar:
		progress_bar.max_value = MAX_HEALTH
		progress_bar.value = health
		progress_bar.visible = false
		
	if not is_multiplayer_authority():
		return
		
	find_players()
	
	# player detection signals
	if not player_detection.body_entered.is_connected(_on_player_detection_body_entered):
		player_detection.body_entered.connect(_on_player_detection_body_entered)
	if not player_detection.body_exited.is_connected(_on_player_detection_body_exited):
		player_detection.body_exited.connect(_on_player_detection_body_exited)
	
	if cave_area:
		cave_area.body_entered.connect(_on_cave_area_body_entered)
		cave_area.body_exited.connect(_on_cave_area_body_exited)
	
	# setup block cooldown timer
	add_child(block_cooldown_timer)
	block_cooldown_timer.one_shot = true
	block_cooldown_timer.wait_time = 10.0  # 10 second cooldown
	block_cooldown_timer.timeout.connect(_on_block_cooldown_timeout)

func is_player(body: Node) -> bool:
	return body.is_in_group("player")

func find_players():
	players = get_tree().get_nodes_in_group("player")
	
	if players.size() == 0:
		# check for player again and again
		await get_tree().create_timer(0.5).timeout
		find_players()
	else:
		find_nearest_player()

func find_nearest_player():
	if not is_multiplayer_authority():
		return
		
	var min_distance = INF
	var nearest_player = null
	
	for body in detected_bodies:
		if body == null or not is_instance_valid(body):
			continue
			
		if is_player(body):
			var distance = position.distance_to(body.position)
			if distance < min_distance:
				min_distance = distance
				nearest_player = body
	
	if nearest_player != player:
		player = nearest_player
		if player != null:
			sync_target_player_id = int(str(player.name))
			direction = player.position - position
			sync_direction = direction
		else:
			sync_target_player_id = -1
			sync_direction = Vector2.ZERO
 
func _process(delta):
	if not is_multiplayer_authority():
		return
		
	if player != null and is_instance_valid(player):
		var new_direction = player.position - position
		if new_direction != direction:
			direction = new_direction
			sync_direction = direction
			if sprite:
				sprite.flip_h = direction.x < 0
				
	check_nearest_timer += delta
	if check_nearest_timer >= CHECK_NEAREST_INTERVAL:
		check_nearest_timer = 0
		find_nearest_player()
 
func _physics_process(delta):
	if not is_multiplayer_authority():
		return
		
	if player != null and is_instance_valid(player):
		velocity = direction.normalized() * MOVEMENT_SPEED
		var collision = move_and_collide(velocity * delta)
		sync_position = position
		
		# check distance for camera zoom for fight
		var distance = position.distance_to(player.position)
		if distance <= 300 and player.has_node("Camera2D"):
			zoom_camera_for_player.rpc(player.get_path(), 3.5)

func _on_player_detection_body_entered(body):
	if not is_multiplayer_authority():
		return
		
	if not body in detected_bodies:
		detected_bodies.append(body)
		
	if is_player(body):
		player_in_range = true
		find_nearest_player()

func _on_player_detection_body_exited(body):
	if not is_multiplayer_authority():
		return
		
	if body in detected_bodies:
		detected_bodies.erase(body)
		
	if body == player:
		player_in_range = false
		find_nearest_player()

@rpc("reliable", "call_local")
func zoom_camera_for_player(player_path: NodePath, zoom_amount: float) -> void:
	var player = get_node_or_null(player_path)
	if player and player.has_node("Camera2D"):
		var tween = create_tween()
		tween.tween_property(player.get_node("Camera2D"), "zoom", Vector2(zoom_amount, zoom_amount), 1.0)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)

func _on_cave_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if is_multiplayer_authority():
			sync_progress_bar_visible = true
		progress_bar.visible = true
		
		if multiplayer.is_server():
			zoom_camera_for_player.rpc(body.get_path(), 2.0)  

func _on_cave_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if is_multiplayer_authority():
			sync_progress_bar_visible = false
		progress_bar.visible = false
		
		if multiplayer.is_server():
			zoom_camera_for_player.rpc(body.get_path(), 4.0) 

func change_state(new_state: String):
	if is_multiplayer_authority():
		sync_state = new_state
	state_machine.change_state(new_state)

func apply_damage(damage_amount: int):
	if not multiplayer.is_server():
		return
	
	health -= damage_amount / armor
	sync_health = health
	
	# Track hits for block state
	var block_state = $FiniteStateMachine/Block
	if block_state and not block_on_cooldown:
		block_state.on_hit()
		if block_state.can_activate(self) and state_machine.current_state.name != "Block":
			block_on_cooldown = true
			block_cooldown_timer.start()
			state_machine.change_state("Block")
	
	if health <= 0:
		sync_animation = "death"
		call_deferred("disable_hitbox")
		Global.bossDoor = true

func disable_hitbox():
	if has_node("HitBox2D/HitBoxCollision2D"):
		$HitBox2D/HitBoxCollision2D.disabled = true

@rpc("any_peer", "reliable")
func request_apply_damage(damage_amount: int, attacker_id: int):
	if not multiplayer.is_server():
		return
	if damage_amount > 0:
		apply_damage(damage_amount)

func _on_hitbox_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("Sword"):
		var attacking_player = area.get_parent()
		
		if attacking_player and attacking_player.has_method("get_current_damage"):
			player_damage = attacking_player.get_current_damage()
			
			if multiplayer.is_server():
				if player_damage > 0:  
					apply_damage(player_damage)
			else:
				request_apply_damage.rpc_id(1, player_damage, multiplayer.get_unique_id())

func _on_block_cooldown_timeout():
	block_on_cooldown = false
