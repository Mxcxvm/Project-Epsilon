extends State

const MELEE_DAMAGE = 18
const ANIMATION_LENGTH = 0.875
const DAMAGE_FRAME = 46  # der frame, an dem damage applied wird

@onready var attack_area = $"../../AttackArea2D"
@onready var sprite = owner.find_child("Sprite2D")

var current_frame = 0

func enter():
	super.enter()
	if owner.is_multiplayer_authority():
		if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
			animation_player.animation_finished.connect(_on_animation_player_animation_finished)
		if not sprite.frame_changed.is_connected(_on_frame_changed):
			sprite.frame_changed.connect(_on_frame_changed)
		if attack_area and not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
			attack_area.body_entered.connect(_on_attack_area_body_entered)
		_start_new_attack()

func exit():
	super.exit()
	if owner.is_multiplayer_authority():
		if animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
			animation_player.animation_finished.disconnect(_on_animation_player_animation_finished)
		if sprite.frame_changed.is_connected(_on_frame_changed):
			sprite.frame_changed.disconnect(_on_frame_changed)
		if attack_area and attack_area.body_entered.is_connected(_on_attack_area_body_entered):
			attack_area.body_entered.disconnect(_on_attack_area_body_entered)
		# Reset attack area
		if attack_area:
			attack_area.scale.x = 1
			attack_area.monitoring = false
			attack_area.monitorable = false

func _start_new_attack():
	owner.sync_animation = "melee_attack"
	
	# Reset attack area for new attack
	if attack_area:
		attack_area.monitoring = false
		attack_area.monitorable = false
		if owner.direction.x < 0:
			attack_area.scale.x = -1
		else:
			attack_area.scale.x = 1

func _physics_process(_delta):
	super._physics_process(_delta)
	if not owner.is_multiplayer_authority():
		return
		
	if owner.player == null:
		owner.change_state("Idle")  
	elif owner.direction.length() > 30:
		owner.change_state("Follow")

func _on_frame_changed():
	if not owner.is_multiplayer_authority():
		return
		
	current_frame = sprite.frame
	if current_frame == DAMAGE_FRAME:
		if attack_area:
			attack_area.monitoring = true
			attack_area.monitorable = true
			_apply_damage()  # damaged alle in range sich befindeten spielern
	elif current_frame != DAMAGE_FRAME:
		if attack_area:
			attack_area.monitoring = false
			attack_area.monitorable = false

func _apply_damage():
	if attack_area:
		var bodies = attack_area.get_overlapping_bodies()
		for body in bodies:
			if body.has_method("take_damage"):
				body.take_damage(MELEE_DAMAGE)

func _on_attack_area_body_entered(body: Node2D):
	if not owner.is_multiplayer_authority():
		return
		
	if current_frame == DAMAGE_FRAME and body.has_method("take_damage"):
		body.take_damage(MELEE_DAMAGE)

func _on_animation_player_animation_finished(anim_name: String):
	if not owner.is_multiplayer_authority():
		return
		
	if anim_name == "melee_attack":
		if owner.player == null:
			owner.change_state("Idle")  
		elif owner.direction.length() > 30:
			owner.change_state("Follow")  
		else:
			_start_new_attack()
