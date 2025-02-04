extends AnimatedSprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer as AnimationPlayer
@onready var animation_player_topPart: AnimationPlayer = $"../../elevator_top_part/AnimationPlayer" as AnimationPlayer
@onready var animated_sprite_2d = $"."
@onready var jammed_text = $"../../Text/Elevator_Jammed_Text"
@onready var interaction_text = $"../../Text/Elevator_Interaction_Text"
@onready var recall_station_active = $"../../Text/Call_Elevator"
@onready var recall_station_inactive = $"../../Text/Recall_Station_Inactive"
@onready var control_station_interaction = $"../../Text/Control_Station"
var player_in_elevator = false
var elevator_started = false
var elevator_recall = false
var elevator_repaired = false
var elevator_controlstation = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
@onready var elevator_fixing_sound: AudioStreamPlayer2D = $"../../elevator_top_part/elevator_fixing_sound"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if  Input.is_action_just_pressed("Interact") and player_in_elevator and elevator_repaired and not elevator_started:
			animated_sprite_2d.play("close_elevator")
			animation_player.play("elevator_up")
			elevator_started = true
			interaction_text.visible = false
			
	if Input.is_action_just_pressed("Interact") and elevator_recall:
			animation_player.play_backwards("elevator_up") 
			animated_sprite_2d.play("open_elevator")
			elevator_started = false
			
	if  Input.is_action_just_pressed("Interact") and elevator_controlstation and not elevator_repaired:
		control_station_interaction.visible = false
		elevator_repaired = true
		animation_player_topPart.play("elevator_repair")
		elevator_fixing_sound.play()
		animated_sprite_2d.play("open_elevator")

#utility function to interrupt the script execution for the given seconds
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _on_elevator_activator_area_body_entered(body: Node2D) -> void:
		if elevator_repaired:
			player_in_elevator = true
			interaction_text.visible = true
		if not elevator_repaired:
			player_in_elevator = true
			jammed_text.visible = true
func _on_elevator_activator_area_body_exited(body: Node2D) -> void:
		player_in_elevator = false
		interaction_text.visible = false
		jammed_text.visible = false

func _on_elevator_recall_area_body_entered(body: Node2D) -> void:
	if elevator_repaired:
		elevator_recall = true
		recall_station_active.visible = true
	if not elevator_repaired:
		recall_station_inactive.visible = true

func _on_elevator_recall_area_body_exited(body: Node2D) -> void:
	elevator_recall = false
	recall_station_active.visible = false
	recall_station_inactive.visible = false

func _on_elevator_control_area_body_entered(body: Node2D) -> void:
	elevator_controlstation = true
	if not elevator_repaired:
		control_station_interaction.visible = true


func _on_elevator_control_area_body_exited(body: Node2D) -> void:
	elevator_controlstation = false
	control_station_interaction.visible = false
