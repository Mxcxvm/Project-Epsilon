extends State
 
@onready var pivot = $"../../Pivot"
@onready var laser_sprite = $"../../Pivot/Sprite2D"
@onready var laser_area = $"../../Pivot/LaserArea2D"
const LASER_WARMUP_TIME := 0.65
const LASER_DAMAGE := 5  # damage pro tick, 50 max.
const DAMAGE_TICK_TIME := 0.1  # damage tick time
var current_phase := "cast"  # "cast" oder "laser"
var animation_started := false
var laser_hit_time = 0.0
var time_since_last_damage := 0.0
var bodies_in_laser = []
var is_laser_active = false

func _ready():
	laser_area.body_entered.connect(_on_laser_body_entered)
	laser_area.body_exited.connect(_on_laser_body_exited)
	laser_area.monitoring = false
	laser_area.monitorable = false

func enter():
	if not owner.is_multiplayer_authority():
		laser_sprite.visible = true
		return
	
	super.enter()
	
	if animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_player_animation_finished)

	if owner.player:
		owner.sprite.flip_h = owner.direction.x < 0
		_update_aim()
	
	current_phase = "cast"
	animation_started = false
	laser_sprite.frame = 0
	laser_sprite.visible = true
	laser_hit_time = 0.0
	time_since_last_damage = 0.0
	bodies_in_laser.clear()
	is_laser_active = false
	laser_area.monitoring = false
	laser_area.monitorable = false

func exit():
	super.exit()
	if animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_player_animation_finished)
	laser_sprite.visible = false
	laser_area.monitoring = false
	laser_area.monitorable = false
	is_laser_active = false
	bodies_in_laser.clear()

func _physics_process(delta):
	if not owner.is_multiplayer_authority():
		return
	
	if not animation_started:
		owner.sync_animation = "laser_cast"
		animation_started = true
		if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
			animation_player.animation_finished.connect(_on_animation_player_animation_finished)
		return
	
	if owner.player == null:
		owner.change_state("Follow")
		return
	
	# update richtung und ziel waehrend casting
	if current_phase == "cast":
		owner.direction = owner.position.direction_to(owner.player.position)
		owner.sprite.flip_h = owner.direction.x < 0
		_update_aim()
	elif current_phase == "laser" and is_laser_active:
		laser_hit_time += delta
		
		# die animation braucht kurz bevor der laser kommt deswegen kleine verzoegerung
		if laser_hit_time < LASER_WARMUP_TIME:
			return
			
		time_since_last_damage += delta
		if time_since_last_damage >= DAMAGE_TICK_TIME:
			time_since_last_damage = 0.0
			
			for body in bodies_in_laser:
				if body.has_method("take_damage") and not body.is_dead:
					body.take_damage(LASER_DAMAGE)

func _update_aim():
	# berechnung von richtung
	var target_pos = owner.player.position
	var pivot_global_pos = pivot.global_position
	
	var angle = (target_pos - pivot_global_pos).angle()
	
	if owner.sprite.flip_h:
		if angle < 0:
			angle += 2 * PI
		angle = clampf(angle, PI/2, 3*PI/2)
	else:
		angle = wrapf(angle, -PI, PI)
		angle = clampf(angle, -PI/2, PI/2)
	
	pivot.rotation = angle
	if owner.is_multiplayer_authority():
		owner.sync_pivot_rotation = angle

func _on_laser_body_entered(body):
	if not is_laser_active:
		return
	if body not in bodies_in_laser and body != owner:
		bodies_in_laser.append(body)

func _on_laser_body_exited(body):
	if body in bodies_in_laser:
		bodies_in_laser.erase(body)

func _on_animation_player_animation_finished(anim_name: String):
	if not owner.is_multiplayer_authority():
		return
		
	if anim_name == "laser_cast":
		current_phase = "laser"
		is_laser_active = true  
		laser_area.monitoring = true
		laser_area.monitorable = true
		owner.sync_animation = "Laser"
	elif anim_name == "Laser":
		owner.change_state("Follow")
