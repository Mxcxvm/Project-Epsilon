extends State

var can_transition : bool = false
const HEALTH_RESTORE_AMOUNT : int = 25
const DAMAGE_REDUCTION : float = 0.25
const HITS_TO_TRIGGER : int = 5
const HIT_WINDOW : float = 3.0
const HP_THRESHOLD_PERCENT : float = 0.5

var recent_hits : int = 0
var hit_timer : float = 0.0

func enter():
	super.enter()
	if owner.is_multiplayer_authority():
		owner.health = min(owner.health + HEALTH_RESTORE_AMOUNT, owner.MAX_HEALTH)
		var previous_state = get_parent().previous_state.name
		animation_player.play("block")
		await animation_player.animation_finished
		owner.sync_state = previous_state
		owner.sync_animation = ""
		get_parent().change_state(previous_state)

func exit():
	super.exit()
	can_transition = false

func physics_process(delta: float) -> void:
	if hit_timer > 0:
		hit_timer -= delta
		if hit_timer <= 0:
			recent_hits = 0

func transition():
	if can_transition:
		return "Follow"
	return null

static func can_activate(character_node) -> bool:
	var current_hp_percent = float(character_node.health) / character_node.MAX_HEALTH
	if current_hp_percent > HP_THRESHOLD_PERCENT:
		return false
	return character_node.get_node("FiniteStateMachine/Block").recent_hits >= HITS_TO_TRIGGER

# aufruf, wenn golem damage bekommt
func on_hit():
	var current_hp_percent = float(owner.health) / owner.MAX_HEALTH
	if current_hp_percent > HP_THRESHOLD_PERCENT:
		return
		
	if hit_timer <= 0:
		recent_hits = 1
	else:
		recent_hits += 1
	hit_timer = HIT_WINDOW
