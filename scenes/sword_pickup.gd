extends Node2D

@onready var interaction_area: InteractionArea = $InteractionArea
@export var item_resource: Resource

func _ready():
	add_to_group("pickup_items")
	interaction_area.interact = Callable(self, "_on_interact")

func _on_interact():
	var player = get_tree().get_first_node_in_group("players").get_parent()
	if player and player.has_method("_on_interact"):
		player._on_interact(self)
	return true  # Return true to satisfy the await in the interaction manager
	
func get_item_data() -> ItemData:
	return item_resource
