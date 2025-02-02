extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	# Clear the "players" group to remove any incorrectly added nodes
	for node in get_tree().get_nodes_in_group("players"):
		node.remove_from_group("players")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
