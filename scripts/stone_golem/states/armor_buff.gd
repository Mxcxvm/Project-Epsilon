extends State

var can_transition : bool = false
var buff_applied : bool = false
var armor_buff_thresholds = [50, 40, 30, 20, 10]
var triggered_thresholds = []

func enter():
	super.enter()
	can_transition = false
	buff_applied = false
	
	animation_player.play("armor buff")
	
	if owner.is_multiplayer_authority() and not buff_applied:
		apply_buff()
	
	await animation_player.animation_finished
	can_transition = true

func exit():
	super.exit()
	can_transition = false

func apply_buff():
	buff_applied = true
	owner.armor += 1
	
	# add visual

# check if buff should be applied
func should_activate(stone_golem) -> bool:
	if stone_golem.is_armor_buff_active:
		return false
		
	if stone_golem.health <= 0:  # security check
		return false
		
	var current_health = stone_golem.health
	for threshold in armor_buff_thresholds:
		var threshold_health = (threshold * stone_golem.MAX_HEALTH) / 100.0
		if current_health <= threshold_health and not threshold in triggered_thresholds:
			triggered_thresholds.append(threshold)
			return true
	return false

func transition():
	if can_transition:
		return "Follow"
	return null
