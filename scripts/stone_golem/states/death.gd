extends State

var death_animation_played = false

func enter():
	super.enter()
	if death_animation_played:
		return
		
	# Disable collision and physics processing
	owner.set_collision_layer_value(1, false)
	owner.set_collision_mask_value(1, false)
	owner.set_physics_process(false)
	
	death_animation_played = true
	# Play death animation
	animation_player.play("death")
	await animation_player.animation_finished
	
	if animation_player.has_animation("boss_slained"):
		animation_player.play("boss_slained")
		await animation_player.animation_finished
	
	if owner.is_multiplayer_authority():
		owner.queue_free()
	else:
		owner.hide()

func exit():
	super.exit()

func transition():
	pass
