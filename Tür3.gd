extends AnimatedSprite2D
@onready var animated_sprite_2d = $"."

var doorOpened: bool = true
var area_one_location = Vector2(1775, -250)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if(doorOpened):
		animated_sprite_2d.play("open_door") # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_2d_body_entered(body: Node2D) -> void:
	#if ("Player" in body.name):
	if(doorOpened):
		body.global_position = area_one_location
