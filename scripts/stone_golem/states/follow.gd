extends State

const MELEE_RANGE = 20
const LASER_RANGE_MIN = 120
const LASER_RANGE_MAX = 260
const MOVEMENT_SPEED = 40

var attack_cooldown = 2.0  # Seconds between attacks
var can_attack = true

func enter():
	super.enter()
	owner.set_physics_process(true)
	if owner.is_multiplayer_authority():
		owner.sync_animation = "idle"
	if debug:
		debug.text = "Follow"
		debug.visible = true
 
func exit():
	super.exit()
	owner.set_physics_process(false)

func start_cooldown():
	can_attack = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
 
func _physics_process(_delta):
	super._physics_process(_delta)
	if not owner.is_multiplayer_authority():
		return
		
	if owner.player == null:
		owner.change_state("Idle")
		return
		
	var distance = owner.position.distance_to(owner.player.position)
	owner.direction = owner.position.direction_to(owner.player.position)
	
	# movement towards player with wall sliding
	if distance > 20:
		var velocity = owner.direction.normalized() * MOVEMENT_SPEED
		owner.velocity = velocity
		owner.move_and_slide()
		owner.sync_position = owner.position
 
	# Check attack ranges
	if distance < MELEE_RANGE:
		owner.change_state("MeleeAttack")
	elif distance >= LASER_RANGE_MIN and distance <= LASER_RANGE_MAX and can_attack:
		owner.change_state("LaserBeam")
		start_cooldown()
	elif distance > LASER_RANGE_MAX and can_attack:
		owner.change_state("RangedAttack")
		start_cooldown()
