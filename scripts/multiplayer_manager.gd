extends Node

# Network config
const PORT = 7000
var enet_peer = ENetMultiplayerPeer.new()
var player_scene = preload("res://scenes/player.tscn")
var enemy_scene = preload("res://scenes/Enemy.tscn")

var enemy_types = {
	"slime": preload("res://scenes/Enemy.tscn"),
}

var connected_players = []

func _ready():
	# check if server needs to be instantiated
	if multiplayer.is_server():
		print("Server initializing world objects...")
		await get_tree().create_timer(0.1).timeout
		call_deferred("assign_world_authority")
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func spawn_player(peer_id):
	# Check if Players node exists
	var players_node = get_tree().get_first_node_in_group("players_container")
	if not players_node:
		print("ERROR: No Players node found!")
		return false
	
	# small timeout for synchronization
	await get_tree().create_timer(0.1).timeout
	
	# check for player spawner in scene
	var spawner = get_tree().get_first_node_in_group("player_spawner")
	print("Spawner found: ", spawner != null)
	if spawner:
		# create instance of preload-scene
		if player_scene:
			print("Player scene loaded successfully")
			var player = player_scene.instantiate()
			if player:
				print("Player instantiated successfully")
				player.name = str(peer_id)
				
				# add player to container node
				players_node.add_child(player, true)
				
				# connect signals to HUD if this is the local player
				if peer_id == multiplayer.get_unique_id():
					var hud = get_tree().get_first_node_in_group("hud")
					if hud:
						# check if signal is not already connected before connecting
						if not player.stamina_value.is_connected(hud._on_player_stamina_value_change):
							player.stamina_value.connect(hud._on_player_stamina_value_change)
				connected_players.append(peer_id)
				return true
			else:
				print("Failed to instantiate player")
		else:
			print("Failed to load player scene")
	
	# fallback option
	if spawner and spawner is MultiplayerSpawner:
		print("Found spawner, attempting spawn...")
		# Spawn the player
		spawner.spawn([peer_id])
		print("Spawn command sent for peer: ", peer_id)
		return true
	else:
		print("ERROR: No valid spawner found in group 'player_spawner'")
	return false


func host_game():
	print("Starting host game...")
	var error = enet_peer.create_server(PORT)
	if error != OK:
		print("Failed to create server: ", error)
		return
	
	# server is assigned to the multiplayer interface
	multiplayer.multiplayer_peer = enet_peer
	
	# change scene to game
	get_tree().change_scene_to_file("res://scenes/game.tscn")
	await get_tree().create_timer(0.1).timeout
	print("Game scene loaded, attempting to spawn host player...")
	
	
	if multiplayer.is_server():
		# references to the nodes
		var enemies_node = get_tree().get_first_node_in_group("enemies_container")
		var enemy_spawner = get_tree().get_first_node_in_group("enemy_spawner")
		
		if enemy_spawner and enemies_node:
			# spawnpoints for enemies
			var enemy_spawns = [
				{"type": "slime", "pos": Vector2(200, -20)},
				{"type": "slime", "pos": Vector2(250, -20)},
				{"type": "slime", "pos": Vector2(500, -60)}
			]
			
			# spawn enemies
			for spawn in enemy_spawns:
				spawn_enemy(spawn.type, spawn.pos, enemies_node)
	
	spawn_player(multiplayer.get_unique_id())

func join_game(ip_address: String):
	print("Joining game at: ", ip_address)
	
	# close existing connections
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	
	# create client connection
	var error = enet_peer.create_client(ip_address, PORT)
	if error != OK:
		print("Failed to create client: ", error)
		return
	
	# connectionstatus signals
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	multiplayer.multiplayer_peer = enet_peer

func _on_connected_to_server():
	print("Successfully connected to server!")
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_connection_failed():
	print("Failed to connect to server!")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	print("Server disconnected!")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	multiplayer.multiplayer_peer = null

func _on_peer_connected(id: int):
	print("Peer connected: ", id)
	print("Current unique ID: ", multiplayer.get_unique_id())
	
	if multiplayer.is_server():
		print("Server attempting to spawn player...")
		spawn_player(id)
		# authority for world objects (not important for now since objects are not synchronized correctly
		assign_world_authority()

func _on_peer_disconnected(peer_id):
	print("Peer disconnected: ", peer_id)
	# remove player from scene
	var player = get_tree().root.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func assign_world_authority():
	# Wait one frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Find all platforms and set their authority
	var platforms = get_tree().get_nodes_in_group("sync_objects")
	print("Found ", platforms.size(), " world objects to synchronize")
	
	for platform in platforms:
		# Set server as authority for all platforms
		platform.set_multiplayer_authority(1)  # Server (ID 1) controls all platforms
		print("Set authority for platform: ", platform.name, " to server")


func spawn_enemy(enemy_type: String, pos: Vector2, enemies_node: Node):
	# check if enemy type exists, then spawn them
	if enemy_types.has(enemy_type):
		var enemy = enemy_types[enemy_type].instantiate()
		enemy.position = pos
		enemies_node.add_child(enemy, true)
		enemy.sync_position = pos
		# server controls all enemies (ID=1)
		enemy.set_multiplayer_authority(1)
		print("Spawned enemy type: ", enemy_type, " at position: ", pos)
	else:
		print("Enemy type not found: ", enemy_type)
