extends Node2D

@onready var interaction_area: InteractionArea = $InteractionArea
@export var item_resource: Resource

func _ready():
	add_to_group("pickup_items")
	print("Setting up interaction for: ", name)
	interaction_area.interact = Callable(self, "_on_interact")

func _on_interact():
	print("Item interacted with: ", name)
	var player = get_tree().get_first_node_in_group("players")
	if player and player.has_method("_on_interact"):
		print("Calling player's _on_interact function")
		player._on_interact(self)
	else:
		print("Player not found or does not have _on_interact method")
	return true  # Return true to satisfy the await in the interaction manager
	
func get_item_data() -> ItemData:
	return item_resource
