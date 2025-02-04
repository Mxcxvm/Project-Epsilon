extends Node

# Network config
const PORT = 7000
var enet_peer = ENetMultiplayerPeer.new()
var player_scene = preload("res://scenes/player.tscn")
var enemy_scene = preload("res://scenes/Enemy.tscn")
var StoneGolemBoss = preload("res://scenes/StoneGolem.tscn")

var enemy_types = {
	"slime": preload("res://scenes/Enemy.tscn"),
	"stoneGolemBoss": preload("res://scenes/StoneGolem.tscn")
}

var connected_players = []

# network discovery config
const BROADCAST_PORT = 7001
const MAX_PORT_ATTEMPTS = 5
const BROADCAST_INTERVAL = 1.0  # seconds
var udp = PacketPeerUDP.new()
var broadcast_timer = Timer.new()
var searching_for_games = false

func _ready():
	# check ob server instanziiert werden muss
	if multiplayer.is_server():
		print("Server initializing world objects...")
		await get_tree().create_timer(0.1).timeout
		call_deferred("assign_world_authority")
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# add timer fuer broadcasting
	broadcast_timer.wait_time = BROADCAST_INTERVAL
	broadcast_timer.timeout.connect(_broadcast_game)
	add_child(broadcast_timer)

func spawn_player(peer_id):
	var players_node = get_tree().get_first_node_in_group("players_container")
	if not players_node:
		print("ERROR: No Players node found!")
		return false
	
	await get_tree().create_timer(0.1).timeout
	
	var spawner = get_tree().get_first_node_in_group("player_spawner")
	print("Spawner found: ", spawner != null)
	if spawner:
		if player_scene:
			print("Player scene loaded successfully")
			var player = player_scene.instantiate()
			if player:
				print("Player instantiated successfully")
				player.name = str(peer_id)
				
				players_node.add_child(player, true)
				
				# verbindung zum hud
				if peer_id == multiplayer.get_unique_id():
					var hud = get_tree().get_first_node_in_group("hud")
					if hud:
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
	
	_start_broadcasting()
	
	# change scene to game
	get_tree().change_scene_to_file("res://scenes/game.tscn")
	await get_tree().create_timer(0.1).timeout
	print("Game scene loaded, attempting to spawn host player...")
	
	
	if multiplayer.is_server():
		var enemies_node = get_tree().get_first_node_in_group("enemies_container")
		var enemy_spawner = get_tree().get_first_node_in_group("enemy_spawner")
		
		if enemy_spawner and enemies_node:
			# spawnpoints for enemies
			var enemy_spawns = [
				{"type": "slime", "pos": Vector2(1250, -50)},
				{"type": "slime", "pos": Vector2(1350, -50)},
				{"type": "slime", "pos": Vector2(250, -20)},
				{"type": "slime", "pos": Vector2(500, -60)},
				{"type": "slime", "pos": Vector2(-3000, 150)},
				{"type": "slime", "pos": Vector2(-2800, 150)},
				{"type": "slime", "pos": Vector2(-3450, -575)},
				{"type": "slime", "pos": Vector2(-3550, -575)},
				{"type": "slime", "pos": Vector2(-4900, -775)},
				{"type": "slime", "pos": Vector2(-6000, -575)},
				{"type": "slime", "pos": Vector2(-6050, -575)},
				{"type": "slime", "pos": Vector2(-6300, --575)},
				{"type": "slime", "pos": Vector2(-6400, --575)},
				{"type": "slime", "pos": Vector2(3600, -1200)},
				{"type": "slime", "pos": Vector2(3500, -1200)},
				{"type": "stoneGolemBoss", "pos": Vector2(6550, -1000)}
			]
			
			# spawn enemies
			for spawn in enemy_spawns:
				spawn_enemy(spawn.type, spawn.pos, enemies_node)
	
	spawn_player(multiplayer.get_unique_id())

func join_game():
	search_for_games()

func _start_broadcasting():
	# clean up existing connection
	if udp.is_bound():
		udp.close()
		
	# set up udp for broadcasting
	udp.set_broadcast_enabled(true)
	var error = udp.bind(BROADCAST_PORT)
	if error == OK:
		print("Successfully started broadcasting on port ", BROADCAST_PORT)
		broadcast_timer.start()
	else:
		print("Failed to start broadcasting, error: ", error)

func _broadcast_game():
	if multiplayer.is_server():
		var message = JSON.stringify({"game": "Project-Epsilon", "port": PORT})
		udp.set_broadcast_enabled(true)
		udp.set_dest_address("255.255.255.255", BROADCAST_PORT)
		udp.put_packet(message.to_utf8_buffer())

func search_for_games():
	print("Searching for games on local network...")
	if enet_peer:
		enet_peer.close()
		enet_peer = ENetMultiplayerPeer.new()
	
	if udp.is_bound():
		udp.close()
	
	await get_tree().create_timer(0.1).timeout
		
	searching_for_games = true
	udp.set_broadcast_enabled(true)
	
	# try different ports if needed
	var bound = false
	for port_offset in range(MAX_PORT_ATTEMPTS):
		var try_port = BROADCAST_PORT + port_offset
		var error = udp.bind(try_port, "*")
		if error == OK:
			print("Successfully bound to UDP port ", try_port, " for game search")
			bound = true
			break
		else:
			print("Failed to bind UDP to port ", try_port, ", error: ", error)
	
	if not bound:
		print("Failed to bind to any UDP port, falling back to localhost")
		_try_localhost()
		return
	
	await get_tree().create_timer(2.0).timeout
	_check_for_games()

func _check_for_games():
	if not searching_for_games:
		return
		
	while udp.get_available_packet_count() > 0:
		var packet = udp.get_packet()
		var ip = udp.get_packet_ip()
		var data = JSON.parse_string(packet.get_string_from_utf8())
		
		if data and data.get("game") == "Project-Epsilon":
			print("Found game at ", ip)
			_connect_to_game(ip, data.get("port", PORT))
			searching_for_games = false
			udp.close()
			return
	
	# if no games found, try localhost
	print("No games found on network, trying localhost...")
	_try_localhost()

func _try_localhost():
	print("Attempting to connect to localhost...")
	_connect_to_game("127.0.0.1", PORT)

func _connect_to_game(ip, port):
	# clean up existing peer if any
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	if enet_peer:
		enet_peer.close()
		enet_peer = ENetMultiplayerPeer.new()
	
	print("Attempting to connect to ", ip, ":", port)
	var error = enet_peer.create_client(ip, port)
	if error != OK:
		print("Failed to connect to ", ip, ":", port, " error: ", error)
		return
		
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
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
		# authority for world objects (not important for now since objects are not synchronized correctly)
		assign_world_authority()

func _on_peer_disconnected(peer_id):
	print("Peer disconnected: ", peer_id)
	
	if multiplayer.is_server():
		var players_node = get_tree().get_first_node_in_group("players_container")
		if players_node:
			var player = players_node.get_node_or_null(str(peer_id))
			if player:
				if connected_players.has(peer_id):
					connected_players.erase(peer_id)
				player.queue_free()
	
	if peer_id == multiplayer.get_unique_id():
		connected_players.clear()

func assign_world_authority():
	# wait for safety
	await get_tree().process_frame
	
	var platforms = get_tree().get_nodes_in_group("sync_objects")
	print("Found ", platforms.size(), " world objects to synchronize")
	
	for platform in platforms:
		platform.set_multiplayer_authority(1) 
		print("Set authority for platform: ", platform.name, " to server")

func spawn_enemy(enemy_type: String, pos: Vector2, enemies_node: Node):
	# check if enemy type exists, then spawn them
	if enemy_types.has(enemy_type):
		var enemy = enemy_types[enemy_type].instantiate()
		enemy.name = enemy_type
		enemy.position = pos
		enemies_node.add_child(enemy, true)
		enemy.sync_position = pos
		
		enemy.set_multiplayer_authority(1)
		print("Spawned enemy type: ", enemy_type, " at position: ", pos)
	else:
		print("Enemy type not found: ", enemy_type)

func _exit_tree():
	# Clean up network resources when the node is removed
	if udp.is_bound():
		udp.close()
	if broadcast_timer.is_inside_tree():
		broadcast_timer.stop()
	if enet_peer:
		enet_peer.close()
