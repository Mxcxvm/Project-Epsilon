extends Control



func _on_host_pressed():
	MultiplayerManager.host_game()



func _on_join_pressed() -> void:
	MultiplayerManager.join_game()
