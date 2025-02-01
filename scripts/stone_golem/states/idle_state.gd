extends State
 
@onready var collision = $"../../PlayerDetection/CollisionShape2D"

const DETECTION_RANGE = 1300
const FOLLOW_RANGE = 300
 
func enter():
	super.enter()
	animation_player.play("idle")
	if debug:
		debug.text = "Idle"
		debug.visible = true
 
func _physics_process(_delta):
	super._physics_process(_delta)
	if owner.player != null:
		var distance = owner.global_position.distance_to(owner.player.global_position)
		if distance <= DETECTION_RANGE: 
			if distance <= FOLLOW_RANGE:
				owner.change_state("Follow")
			else:
				owner.change_state("RangedAttack")  # default
