extends Area2D
class_name InteractionArea

@export var action_name: String = "interact"

var interact: Callable = func():
	pass
	
func _on_body_entered(body: Node2D) -> void:
	print("Body entered interaction area: ", body.name)
	InteractionManager.register_area(self)

func _on_body_exited(body: Node2D) -> void:
	print("Body exited interaction area: ", body.name)
	InteractionManager.unregister_area(self)
