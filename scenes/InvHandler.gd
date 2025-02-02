extends Node

var InvSize = 16
var itemsLoad = [
	"res://inventory/items/sword.tres",
	"res://inventory/items/helmet.tres",
	"res://inventory/items/chest.tres",
	"res://inventory/items/legs.tres",
	"res://inventory/items/feet.tres",
	"res://inventory/items/axe.tres"
]

func _ready() -> void:
	self.visible = !self.visible
	for i in InvSize:
		var slot := InventorySlot.new()
		slot.init(ItemData.Type.MAIN, Vector2(64, 64))
		%Inv.add_child(slot)
		
	for i in itemsLoad.size():
		var item := InventoryItem.new()
		item.init(load(itemsLoad[i]))
		%Inv.get_child(i).add_child(item)

func toggle_inventory_visibility():
	if not get_parent().is_multiplayer_authority():
		return
	self.visible = !self.visible

func _process(_delta: float) -> void:
	if not get_parent().is_multiplayer_authority():
		return
		
	if Input.is_action_just_pressed("TAB"):
		toggle_inventory_visibility()
