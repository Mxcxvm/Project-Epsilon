extends AnimatedSprite2D

@onready var animated_sprite_2d = $"."
@onready var boss_door_sound: AudioStreamPlayer2D = $boss_door_sound
@onready var synchronizer = $MultiplayerSynchronizer

@export var sync_door_open: bool = false:
	set(value):
		sync_door_open = value
		if not is_multiplayer_authority():
			doorOpen = value

var doorOpen: bool = false:
	set(value):
		doorOpen = value
		if value:
			animated_sprite_2d.play("deactivated")
			boss_door_sound.play()
		if is_multiplayer_authority():
			sync_door_open = value

var last_area_location = Vector2(2550, -10)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animated_sprite_2d.play("activated")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(!doorOpen and Global.bossDoor):
		doorOpen = true

func _on_area_2d_body_entered(body: Node2D) -> void:
	if(Global.bossDoor):
		body.global_position = last_area_location

func _get_configuration_warning() -> String:
	if not get_tree().is_network_server():
		return "This node should be run on the server."
	return ""
