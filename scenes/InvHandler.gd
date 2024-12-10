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
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("TAB"):
		print("changing inv status")
		self.visible = !self.visible	
