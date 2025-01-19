extends AnimatedSprite2D
@onready var animated_sprite_2d = $"."

var state_one: bool = false
var state_two: bool = false
var doorOpened: bool = false
var area_two_location = Vector2(2900, -1360)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(!doorOpened):
		if(state_one): #and state_two
			doorOpened = true
			animated_sprite_2d.play("open_door")



func _on_pressure_plate_door_state(state: Variant) -> void:
	state_one = state


func _on_pressure_plate_2_door_state_two(state: Variant) -> void:
	state_two = state


func _on_area_2d_body_entered(body: Node2D) -> void:
	#if ("Player" in body.name):
	if(doorOpened):
		body.global_position = area_two_location
