class_name ItemData
extends Resource

enum Type {HEAD, CHEST, LEGS, FEET, WEAPON, ACCESSORY, MAIN}

@export var type: Type
@export var name: String
@export var damage: float
@export var defense: float
@export_multiline var description: String
@export var texture: Texture2D
