extends Node

var _boss_door: bool = false
var bossDoor: bool = false:
	set(value):
		_boss_door = value
		if multiplayer.is_server() and value == true:
			sync_boss_door.rpc()
	get:
		return _boss_door

var game_over: bool = false

func _ready() -> void:
	pass 

@rpc("authority", "reliable", "call_local")
func sync_boss_door():
	_boss_door = true

func _process(delta: float) -> void:
	pass
