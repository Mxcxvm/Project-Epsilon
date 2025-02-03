extends State

const MELEE_DAMAGE = 10
var damage_applied = false
var damage_timer = 0.0
const DAMAGE_TIME = 0.75  # when should the damage be applied
const ANIMATION_LENGTH = 0.875

@onready var attack_area = $"../../AttackArea2D"

func enter():
	super.enter()
	if owner.is_multiplayer_authority():
		if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
			animation_player.animation_finished.connect(_on_animation_player_animation_finished)
			
		_start_new_attack()

func _start_new_attack():
	damage_applied = false
	damage_timer = 0.0
	owner.sync_animation = "melee_attack"
	
	# Set up attack area direction
	if attack_area:
		attack_area.monitoring = true
		attack_area.monitorable = true
		# flip attack area based on direction to player
		if owner.direction.x < 0:
			attack_area.scale.x = -1
		else:
			attack_area.scale.x = 1

func exit():
	super.exit()
	if owner.is_multiplayer_authority():
		if animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
			animation_player.animation_finished.disconnect(_on_animation_player_animation_finished)
		# Reset attack area
		if attack_area:
			attack_area.scale.x = 1

func _physics_process(delta):
	super._physics_process(delta)
	if not owner.is_multiplayer_authority():
		return
		
	if owner.player == null:
		owner.change_state("Idle")  
	elif owner.direction.length() > 30:
		owner.change_state("Follow")
		
	# Handle damage timing
	if not damage_applied:
		damage_timer += delta
		if damage_timer >= DAMAGE_TIME:
			_apply_damage()
			damage_applied = true

func _apply_damage():
	# Get all bodies currently in the attack area and damage them
	if attack_area:
		var bodies = attack_area.get_overlapping_bodies()
		for body in bodies:
			if body.has_method("take_damage"):
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
			# Still in range, start a new attack cycle
			_start_new_attack()
