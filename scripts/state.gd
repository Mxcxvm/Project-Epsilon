extends Node2D
class_name State

@onready var animation_player = owner.find_child("AnimationPlayer")
@onready var debug = owner.find_child("debug")

func _ready():
	set_physics_process(false)
	set_process(false)

func enter():
	set_physics_process(true)
	set_process(true)
	if debug:
		debug.text = name
		debug.visible = true

func exit():
	set_physics_process(false)
	set_process(false)
	if debug:
		debug.visible = false

func _physics_process(_delta):
	pass

func _process(_delta):
	pass
