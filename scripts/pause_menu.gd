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
		
# Wenn R esume button geclickt wird, dann hide panel und pausiere
func _on_resume_button_pressed() -> void:
	pause_panel.hide()
	get_tree().paused = false
	
# Wenn Reset geclickt wird dann entpausiere und Lade die scene neu
func _on_reset_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
	
# Wenn Exit Game geclickt wird dann schließe game
func _on_exit_button_pressed() -> void:
	get_tree().quit()
