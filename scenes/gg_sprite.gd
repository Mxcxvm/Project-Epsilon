extends Sprite2D

@onready var gg_text = $"../GG_text"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_gg_area_body_entered(body: Node2D) -> void:
	gg_text.visible
	Global.game_over = false
