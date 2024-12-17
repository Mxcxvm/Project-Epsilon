extends CanvasLayer

var last_health := -1
var last_stamina := -1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("[HUD] Initializing HUD")
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func update_health(health):
	if health == last_health:  # Skip if no change
		return
		
	if has_node("hp_bar"):
		$hp_bar.value = health
		last_health = health
	else:
		print("[HUD] ERROR: Could not find hp_bar node")

func update_stamina(stamina):
	if abs(stamina - last_stamina) < 1.0:  # Skip small changes
		return
		
	if has_node("stamina_bar"):
		$stamina_bar.value = stamina
		last_stamina = stamina
	else:
		print("[HUD] ERROR: Could not find stamina_bar node")

func _on_player_stamina_value_change(current_stamina: Variant) -> void:
	update_stamina(current_stamina)
