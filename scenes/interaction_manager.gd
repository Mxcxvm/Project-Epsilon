extends Node2D

@onready var player = get_tree().get_first_node_in_group("player")
@onready var label = $Label

const base_text = "[E] to "

var active_areas = []
var can_interact = true

func register_area(area: InteractionArea):
	if area not in active_areas:
		active_areas.push_back(area)

func unregister_area(area: InteractionArea):
	active_areas.erase(area)

func _process(delta):
	if active_areas.size() > 0 and can_interact:
		# Sort active areas by distance to the player using a custom function
		active_areas.sort_custom(Callable(self, "_sort_by_distance_to_player"))

		# Show interaction label for the closest area
		var closest_area = active_areas[0]
		label.text = base_text + closest_area.action_name
		label.global_position = closest_area.global_position - Vector2(label.size.x / 2, 36)
		label.show()
	else:
		label.hide()

func _sort_by_distance_to_player(area1, area2):
	var area1_to_player = player.global_position.distance_to(area1.global_position)
	var area2_to_player = player.global_position.distance_to(area2.global_position)
	return area1_to_player < area2_to_player

func _input(event):
	if event.is_action_pressed("Interact") and can_interact:
		if active_areas.size() > 0:
			can_interact = false
			label.hide()
			var closest_area = active_areas[0]
			await closest_area.interact.call()
			can_interact = true
