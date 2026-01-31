## This script is attached to the Player node and is specifically designed to represent player entities in the game.
## The Player node serves as the foundation for creating main playable characters.
class_name PlayerEntity
extends CharacterEntity

@export_group("States")
@export var on_transfer_start: State ## State to enable when player starts transfering.
@export var on_transfer_end: State ## State to enable when player ends transfering.

var player_id: int = 1 ## A unique id that is assigned to the player on creation. Player 1 will have player_id = 1 and each additional player will have an incremental id, 2, 3, 4, and so on.
var equipped = 0 ## The id of the weapon equipped by the player.

@onready var flashlight: FlashlightCone = $FlashlightCone
@onready var mask_effect_manager: MaskEffectManager = $MaskEffectManager
@onready var inventory_slot_hud: InventorySlotHUD = $InventorySlotHUD

func _ready():
	super._ready()
	Globals.transfer_start.connect(func(): 
		on_transfer_start.enable()
	)
	Globals.transfer_complete.connect(func(): on_transfer_end.enable())
	Globals.destination_found.connect(func(destination_path): _move_to_destination(destination_path))
	
	# Sync flashlight with facing direction
	if flashlight:
		direction_changed.connect(_update_flashlight_aim)
		_update_flashlight_aim(facing)
	
	# Setup inventory slot HUD
	if inventory_slot_hud:
		print("PlayerEntity: Found InventorySlotHUD")
		if inventory:
			print("PlayerEntity: Setting inventory on HUD")
			inventory_slot_hud.set_inventory(inventory)
			inventory_slot_hud.item_used.connect(_on_mask_item_used)
		else:
			print("PlayerEntity: Warning - No inventory found")
	else:
		print("PlayerEntity: Warning - InventorySlotHUD not found!")
	
	receive_data(DataManager.get_player_data(player_id))
	
	# Initialize starting inventory if empty (after loading save data)
	if inventory and inventory.items.is_empty():
		_initialize_starting_inventory()
	
	# Refresh HUD after inventory is set up
	if inventory_slot_hud and inventory:
		inventory_slot_hud._refresh_slots()

##Get the player data to save.
func get_data():
	var data = DataPlayer.new()
	var player_data = DataManager.get_player_data(player_id)
	if player_data:
		data = player_data
	data.position = position
	data.facing = facing
	data.hp = health_controller.hp
	data.max_hp = health_controller.max_hp
	data.inventory = inventory.items if inventory else []
	data.equipped = equipped
	return data

##Handle the received player data (from a save file or when moving to another level).
func receive_data(data):
	if data:
		global_position = data.position
		facing = data.facing
		health_controller.hp = data.hp
		health_controller.max_hp = data.max_hp
		if inventory:
			inventory.items = data.inventory
		equipped = data.equipped

func _move_to_destination(destination_path: String):
	if !destination_path:
		return
	var destination = get_tree().root.get_node(destination_path)
	if !destination:
		return
	var direction = facing
	if destination is Transfer and destination.direction:
		direction = destination.direction.to_vector
	DataManager.save_player_data(player_id, {
		position = destination.global_position,
		facing = direction
	})

func disable_entity(value: bool, delay = 0.0):
	await get_tree().create_timer(delay).timeout
	stop()
	input_enabled = !value

## Update flashlight aim direction when player facing changes.
func _update_flashlight_aim(direction: Vector2):
	if flashlight:
		flashlight.set_aim_direction(direction)

## Handle flashlight toggle input.
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed(&"flashlight"):
		if flashlight:
			flashlight.set_enabled(not flashlight.enabled)

## Initialize player's starting inventory with mask items.
func _initialize_starting_inventory():
	if not inventory:
		return
	
	# Create Night Vision Mask item
	var night_vision_mask = DataMaskItem.new()
	night_vision_mask.resource_name = "Night Vision Mask"
	night_vision_mask.mask_type = DataMaskItem.MaskType.NIGHT_VISION
	night_vision_mask.effect_duration = 5.0
	night_vision_mask.icon = _create_simple_icon(32, Color(0.0, 1.0, 0.4, 1.0))  # Green circle
	
	# Create Disguise item
	var disguise = DataMaskItem.new()
	disguise.resource_name = "Disguise"
	disguise.mask_type = DataMaskItem.MaskType.DISGUISE
	disguise.effect_duration = 5.0
	disguise.icon = _create_simple_icon(32, Color(0.6, 0.2, 0.8, 1.0))  # Purple square
	
	# Add items to inventory
	inventory.add_item(night_vision_mask, 3)
	inventory.add_item(disguise, 3)
	
	# Refresh HUD
	if inventory_slot_hud:
		inventory_slot_hud._refresh_slots()

## Create a simple colored icon texture.
func _create_simple_icon(size: int, color: Color) -> AtlasTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	
	var texture = ImageTexture.create_from_image(image)
	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, size, size)
	return atlas

## Handle mask item usage.
func _on_mask_item_used(item: DataItem):
	if not item is DataMaskItem:
		return
	
	var mask_item = item as DataMaskItem
	if not mask_effect_manager:
		return
	
	match mask_item.mask_type:
		DataMaskItem.MaskType.NIGHT_VISION:
			mask_effect_manager.apply_night_vision(mask_item.effect_duration)
		DataMaskItem.MaskType.DISGUISE:
			mask_effect_manager.apply_disguise(mask_item.effect_duration)
