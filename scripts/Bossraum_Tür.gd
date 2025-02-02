extends AnimatedSprite2D
@onready var animated_sprite_2d = $"."
@onready var key = $"../../Keyitems/Doorkey"
@onready var door_locked_text = $"../../Text/Door_Locked_Text"

var doorOpened: bool = false
var keyCollected: bool = false
var area_two_location = Vector2(5200, -1430)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if(!doorOpened):
		if(keyCollected): #and state_two
			doorOpened = true
			animated_sprite_2d.play("open_door")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_2d_body_entered(body: Node2D) -> void:
	#if ("Player" in body.name):
	if(doorOpened):
		body.global_position = area_two_location
	if(!keyCollected):
		door_locked_text.visible = true


func _on_key_collection_area_body_entered(body: Node2D) -> void:
	keyCollected = true
	key.visible = false


func _on_area_2d_body_exited(body: Node2D) -> void:
	door_locked_text.visible = false
