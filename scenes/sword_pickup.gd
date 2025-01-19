extends Node2D


@onready var interaction_area: InteractionArea = $InteractionArea
#To interact with stuff	

func _ready():
	interaction_area.interact = Callable(self, "_on_interact")

func _on_interact():
	await print("Interacted")
