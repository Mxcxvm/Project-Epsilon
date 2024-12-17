extends Control



func _on_host_pressed():
	MultiplayerManager.host_game()



func _on_join_pressed() -> void:
	var ip = "localhost"
	MultiplayerManager.join_game(ip)
