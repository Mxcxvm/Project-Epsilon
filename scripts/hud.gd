extends CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func update_health(health):
	$hp_bar.value = health

func update_stamina(stamina):
	$stamina_bar.value = stamina

func _on_player_stamina_value_change(current_stamina: Variant) -> void:
	update_stamina(current_stamina)
