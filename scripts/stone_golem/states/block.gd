extends State

var can_transition : bool = false
var block_cooldown : float = 0.0
const BLOCK_COOLDOWN_TIME : float = 10.0
const HEALTH_RESTORE_AMOUNT : int = 30
const BLOCK_CHANCE : float = 0.1
const HP_THRESHOLD_PERCENT : float = 0.5

func enter():
	super.enter()
	if owner.is_multiplayer_authority():
		owner.health = min(owner.health + HEALTH_RESTORE_AMOUNT, owner.MAX_HEALTH)
		block_cooldown = BLOCK_COOLDOWN_TIME
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
	if block_cooldown > 0:
		block_cooldown -= delta

func transition():
	if can_transition:
		return "Follow"
	return null

static func can_activate(character_node) -> bool:
	var state = character_node.get_node("FiniteStateMachine/Block")
	if state.block_cooldown > 0:
		return false
	
	var current_hp_percent = float(character_node.health) / character_node.MAX_HEALTH
	if current_hp_percent > HP_THRESHOLD_PERCENT:
		return false
	print("DID IT WORK???????")
	return randf() < BLOCK_CHANCE
