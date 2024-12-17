extends Node

var InvSize = 16
var itemsLoad = [
	"res://inventory/items/sword.tres"
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.visible = !self.visible
	for i in InvSize:
		var slot := InventorySlot.new()
		slot.init(ItemData.Type.MAIN, Vector2(32, 32))
		%Inv.add_child(slot)
		
	for i in itemsLoad.size():
		var item := InventoryItem.new()
		item.init(load(itemsLoad[i]))
		%Inv.get_child(i).add_child(item)

func toggle_inventory_visibility():
	# Only process actions for owner of this inventory
	if not get_parent().is_multiplayer_authority():
		return
	self.visible = !self.visible

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Only process input for the owner of this inventory
	if not get_parent().is_multiplayer_authority():
		return
		
	if Input.is_action_just_pressed("TAB"):
		toggle_inventory_visibility()
