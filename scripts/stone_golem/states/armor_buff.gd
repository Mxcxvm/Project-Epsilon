extends State

var can_transition : bool = false
var buff_applied : bool = false
var evolution_thresholds = [75, 50, 25]  # hp prozent wert fuer evolution
var triggered_thresholds = []

const ARMOR_INCREASE : float = 0.1  # 10% armor increase pro evolution
const DAMAGE_INCREASE : float = 0.15  # 15% damage increase pro evolution

func enter():
	super.enter()
	can_transition = false
	buff_applied = false
	
	animation_player.play("armor buff")
	
	if owner.is_multiplayer_authority() and not buff_applied:
		apply_buff()
		pass
	
	await animation_player.animation_finished
	can_transition = true

func exit():
	super.exit()
	can_transition = false

func apply_buff():
	buff_applied = true
	owner.armor += ARMOR_INCREASE
	owner.player_damage *= (1 + DAMAGE_INCREASE)

# check ob buff aktiviert werden soll
func should_activate(stone_golem) -> bool:
	if stone_golem.is_armor_buff_active:
		return false
		
	if stone_golem.health <= 0:  # security check
		return false
		
	var current_health_percent = (stone_golem.health * 100.0) / stone_golem.MAX_HEALTH
	
	for threshold in evolution_thresholds:
		if current_health_percent <= threshold and not threshold in triggered_thresholds:
			triggered_thresholds.append(threshold)
			return true
	return false

func transition():
	if can_transition:
		return "Follow"
	return null
