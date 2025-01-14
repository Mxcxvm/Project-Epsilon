extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_2d_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
		
	if body.name.is_valid_int():  # Check if it's a player
		if body.has_method("knockback"):
			var x = body.position.x - position.x
			var peer_id = body.name.to_int()
			
			# If its the host player apply knockback directly
			if peer_id == 1:
				body.knockback(700 if x > 0 else -700, 30)
			else:
				# For clients use RPC
				body.knockback.rpc_id(peer_id, 700 if x > 0 else -700, 30)
