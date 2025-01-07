extends Node2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer as AnimationPlayer
#@export var toggle: bool = false
#var state: bool = false
# Called when the node enters the scene tree for the first time.
var state: bool = false;
signal door_state(state)
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_2d_body_entered(body: Node2D) -> void:
	#if (!doorOpened):
		animation_player.play("activate")
		state = true
		door_state.emit(state)
	#else:
		#if (state):
			#animation_player.play("disable")
		#else:
			#animation_player.play("activate")
#
	#state = !state
	

func _on_area_2d_body_exited(body: Node2D) -> void:
	#if (!toggle):
		animation_player.play("disable")
