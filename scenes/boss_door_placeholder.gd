extends AnimatedSprite2D
@onready var animated_sprite_2d = $"."
@onready var boss_door_sound: AudioStreamPlayer2D = $boss_door_sound
var doorOpen: bool = false
var last_area_location = Vector2(2550, -10)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animated_sprite_2d.play("activated")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(!doorOpen):
		if(Global.bossDoor):
			doorOpen = true
			animated_sprite_2d.play("deactivated")
			boss_door_sound.play()

func _on_area_2d_body_entered(body: Node2D) -> void:
		if(Global.bossDoor):
			body.global_position = last_area_location
