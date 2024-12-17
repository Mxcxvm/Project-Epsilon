extends CanvasLayer

@onready var health_bar = $Control/hp_bar
@onready var stamina_bar = $Control/stamina_bar

func _ready() -> void:
	# Set up initial values
	if health_bar:
		health_bar.max_value = 100
		health_bar.value = 100
	if stamina_bar:
		stamina_bar.max_value = 100
		stamina_bar.value = 100

func update_health(health: int) -> void:
	if health_bar:
		health_bar.value = health

func update_stamina(stamina: float) -> void:
	if stamina_bar:
		stamina_bar.value = stamina

func _on_player_stamina_value_change(value: float) -> void:
	update_stamina(value)
