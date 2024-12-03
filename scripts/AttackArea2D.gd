extends Area2D

var damage = 0

func _ready():
	monitoring = true
	monitorable = true

func _on_body_entered(body):
	if body.has_method("take_damage") and body != get_parent():  # Verhindert Selbst-Schaden
		body.take_damage(damage)
		print("Hit enemy with ", damage, " damage!")  # Optional: Debug-Ausgabe 