extends Node

@onready var pause_panel: Panel = %"Pause Panel"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Pause"):
		get_tree().paused = true
		pause_panel.show()
		
func _on_resume_button_pressed() -> void:
	pause_panel.hide()
	get_tree().paused = false

func _on_go_to_main_menu_pressed() -> void:
	get_tree().quit()

func _on_options_pressed() -> void:
	pass # Replace with function body.
