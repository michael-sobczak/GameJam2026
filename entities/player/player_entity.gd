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
@onready var active_mask_icon: TextureRect = $ActiveMaskIcon

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

	# Apply level mask restrictions (e.g. level 3 = no disguise mask); strip disallowed masks
	call_deferred("_apply_level_mask_restrictions")

	# Refresh HUD after inventory is set up
	if inventory_slot_hud and inventory:
		inventory_slot_hud._refresh_slots()

	# Floating mask icon above player (same size as hotbar icon)
	if mask_effect_manager and active_mask_icon:
		mask_effect_manager.active_mask_changed.connect(_on_active_mask_icon_changed)
		_on_active_mask_icon_changed(mask_effect_manager.active_mask_texture, mask_effect_manager.active_mask_name)

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

## Update flashlight aim direction and position when player facing changes.
func _update_flashlight_aim(direction: Vector2):
	if not flashlight:
		return

	flashlight.set_aim_direction(direction)

	# Offset flashlight position based on facing direction (torch held in right hand)
	var offset := Vector2.ZERO
	if direction == Vector2.DOWN:
		offset = Vector2(8, 0)  # Torch visible on right side
	elif direction == Vector2.UP:
		offset = Vector2(-8, -10)  # Torch behind, slightly left
	elif direction == Vector2.LEFT:
		offset = Vector2(0, -5)  # Torch behind player
	elif direction == Vector2.RIGHT:
		offset = Vector2(8, -5)  # Torch in front on right
	else:
		# Diagonal directions
		offset = Vector2(direction.x * 6, direction.y * 3 - 5)

	flashlight.position = offset

## Handle flashlight toggle input.
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed(&"flashlight"):
		if flashlight:
			flashlight.set_enabled(not flashlight.enabled)
			AudioManager.play_sfx("flashlight_toggle")

## Preloaded mask textures.
const NIGHT_VISION_MASK_TEXTURE = preload("res://DownloadedAssets/a-stunning-masquerade-mask-featuring-elaborate-detailing-and-a-rich-palette-of-purple-green-and-pink-hues-evoking-mystery-and-festivity-png.png")
const DISGUISE_MASK_TEXTURE = preload("res://DownloadedAssets/elaborate-venetian-mask-with-wings-gold-details-and-gems-on-transparent-background-png.png")
const REFLECTION_MASK_TEXTURE = preload("res://DownloadedAssets/mask3.jpeg")

## Preloaded mask sound effects (distinct for each mask type).
const NIGHT_VISION_ACTIVATE_SFX = preload("res://Kenny Audio Pack/Audio/glitch_003.ogg")
const NIGHT_VISION_DEACTIVATE_SFX = preload("res://Kenny Audio Pack/Audio/glitch_001.ogg")
const DISGUISE_ACTIVATE_SFX = preload("res://Kenny Audio Pack/Audio/maximize_008.ogg")
const DISGUISE_DEACTIVATE_SFX = preload("res://Kenny Audio Pack/Audio/minimize_008.ogg")
const REFLECTION_ACTIVATE_SFX = preload("res://Kenny Audio Pack/Audio/maximize_006.ogg")
const REFLECTION_DEACTIVATE_SFX = preload("res://Kenny Audio Pack/Audio/pluck_001.ogg")

## Initialize player's starting inventory with the appropriate mask items for the level.
func _initialize_starting_inventory():
	if not inventory:
		print("PlayerEntity: Cannot initialize inventory - inventory is null")
		return

	var allowed := _get_level_allowed_mask_types()
	var qty_per_mask: int = _get_usages_per_mask()
	print("PlayerEntity: Initializing starting inventory...")

	# Create Night Vision Mask item (add only if allowed)
	if allowed.is_empty() or "night_vision" in allowed:
		var night_vision_mask = DataMaskItem.new()
		night_vision_mask.resource_name = "Night Vision Mask"
		night_vision_mask.description = "See clearly in the dark for a short time."
		night_vision_mask.mask_type = DataMaskItem.MaskType.NIGHT_VISION
		night_vision_mask.effect_duration = 5.0
		night_vision_mask.icon = _create_atlas_from_texture(NIGHT_VISION_MASK_TEXTURE)
		night_vision_mask.mask_texture = NIGHT_VISION_MASK_TEXTURE
		night_vision_mask.activate_sound = NIGHT_VISION_ACTIVATE_SFX
		night_vision_mask.deactivate_sound = NIGHT_VISION_DEACTIVATE_SFX
		inventory.add_item(night_vision_mask, qty_per_mask)
		print("PlayerEntity: Created Night Vision Mask, icon: %s" % night_vision_mask.icon)

	# Create Disguise Mask item (add only if allowed)
	if allowed.is_empty() or "disguise" in allowed:
		var disguise = DataMaskItem.new()
		disguise.resource_name = "Disguise Mask"
		disguise.description = "Blend in with enemies and avoid detection."
		disguise.mask_type = DataMaskItem.MaskType.DISGUISE
		disguise.effect_duration = 5.0
		disguise.icon = _create_atlas_from_texture(DISGUISE_MASK_TEXTURE)
		disguise.mask_texture = DISGUISE_MASK_TEXTURE
		disguise.activate_sound = DISGUISE_ACTIVATE_SFX
		disguise.deactivate_sound = DISGUISE_DEACTIVATE_SFX
		inventory.add_item(disguise, qty_per_mask)
		print("PlayerEntity: Created Disguise Mask, icon: %s" % disguise.icon)

	# Create Reflection Mask item (add only if allowed)
	if allowed.is_empty() or "reflection" in allowed:
		var reflection = DataMaskItem.new()
		reflection.resource_name = "Mask of Reflection"
		reflection.description = "Reflect laser beams back at their source."
		reflection.mask_type = DataMaskItem.MaskType.REFLECTION
		reflection.effect_duration = 5.0
		reflection.icon = _create_atlas_from_texture(REFLECTION_MASK_TEXTURE)
		reflection.mask_texture = REFLECTION_MASK_TEXTURE
		reflection.activate_sound = REFLECTION_ACTIVATE_SFX
		reflection.deactivate_sound = REFLECTION_DEACTIVATE_SFX
		inventory.add_item(reflection, qty_per_mask)
		print("PlayerEntity: Created Mask of Reflection, icon: %s" % reflection.icon)

	# Create Phase Mask item (add only if allowed) — walk through walls; expels when effect ends if inside a wall
	if allowed.is_empty() or "phase" in allowed:
		var phase = DataMaskItem.new()
		phase.resource_name = "Phase Mask"
		phase.description = "Walk through walls for a short time. Expels you when it ends if you're inside a wall."
		phase.mask_type = DataMaskItem.MaskType.PHASE
		phase.effect_duration = 5.0
		phase.icon = _create_atlas_from_texture(DISGUISE_MASK_TEXTURE)
		phase.mask_texture = DISGUISE_MASK_TEXTURE
		phase.activate_sound = DISGUISE_ACTIVATE_SFX
		phase.deactivate_sound = DISGUISE_DEACTIVATE_SFX
		inventory.add_item(phase, qty_per_mask)
		print("PlayerEntity: Created Phase Mask, icon: %s" % phase.icon)

	print("PlayerEntity: Added items to inventory, total items: %d" % inventory.items.size())

	# Refresh HUD
	if inventory_slot_hud:
		print("PlayerEntity: Refreshing inventory slot HUD...")
		inventory_slot_hud._refresh_slots()
	else:
		print("PlayerEntity: Warning - inventory_slot_hud is null, cannot refresh")

## Level that owns this player (ancestor in group LEVEL). Use this instead of get_current_level() so mask config is correct during scene transition when two levels exist in the tree.
func _get_own_level() -> Node:
	var n: Node = get_parent()
	while n:
		if n.is_in_group(Const.GROUP.LEVEL):
			return n
		n = n.get_parent()
	return null

## Get allowed mask type keys from the level that owns this player. Empty = all masks allowed.
func _get_level_allowed_mask_types() -> Array[String]:
	var level = _get_own_level()
	if not level or not level.get("allowed_mask_types"):
		return []
	var arr: Array = level.allowed_mask_types
	var result: Array[String] = []
	for s in arr:
		if s is String:
			result.append(s as String)
	return result

## Get starting usages per mask from the level that owns this player. Uses 3 if missing or <= 0.
func _get_usages_per_mask() -> int:
	var level = _get_own_level()
	if not level or not level.get("usages_per_mask"):
		return 3
	var q: int = level.usages_per_mask
	return q if q > 0 else 3

## Remove from inventory any mask items not allowed on the current level. Call deferred so level is ready.
func _apply_level_mask_restrictions():
	if not inventory:
		return
	var allowed := _get_level_allowed_mask_types()
	if allowed.is_empty():
		return
	var to_remove: Array[Dictionary] = []
	for content in inventory.items:
		if content.item is DataMaskItem:
			var mask_item := content.item as DataMaskItem
			var type_key := DataMaskItem.type_to_string(mask_item.mask_type)
			if type_key not in allowed:
				to_remove.append({ "name": mask_item.resource_name, "qty": content.quantity })
	for entry in to_remove:
		inventory.remove_item(entry.name, entry.qty)
	if not to_remove.is_empty() and inventory_slot_hud:
		inventory_slot_hud._refresh_slots()

## Create an AtlasTexture from a full texture for use as an icon.
func _create_atlas_from_texture(texture: Texture2D) -> AtlasTexture:
	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, texture.get_width(), texture.get_height())
	return atlas

## Handle mask item usage. Only consume when effect is actually applied (not already active).
func _on_mask_item_used(mask_item: DataMaskItem):
	if not mask_effect_manager:
		return

	var can_apply := false
	match mask_item.mask_type:
		DataMaskItem.MaskType.NIGHT_VISION:
			can_apply = mask_effect_manager.can_apply_night_vision()
			if can_apply:
				mask_effect_manager.apply_night_vision(
					mask_item.effect_duration,
					mask_item.mask_texture,
					mask_item.activate_sound,
					mask_item.deactivate_sound,
					mask_item.resource_name
				)
		DataMaskItem.MaskType.DISGUISE:
			can_apply = mask_effect_manager.can_apply_disguise()
			if can_apply:
				mask_effect_manager.apply_disguise(
					mask_item.effect_duration,
					mask_item.mask_texture,
					mask_item.activate_sound,
					mask_item.deactivate_sound,
					mask_item.resource_name
				)
		DataMaskItem.MaskType.REFLECTION:
			can_apply = mask_effect_manager.can_apply_reflection()
			if can_apply:
				mask_effect_manager.apply_reflection(
					mask_item.effect_duration,
					mask_item.mask_texture,
					mask_item.activate_sound,
					mask_item.deactivate_sound,
					mask_item.resource_name
				)
		DataMaskItem.MaskType.PHASE:
			can_apply = mask_effect_manager.can_apply_phase()
			if can_apply:
				mask_effect_manager.apply_phase(
					mask_item.effect_duration,
					mask_item.mask_texture,
					mask_item.activate_sound,
					mask_item.deactivate_sound,
					mask_item.resource_name
				)

	if not can_apply:
		return

	# Effect was applied: consume one use and refresh HUD
	AudioManager.play_sfx("item_use")
	if inventory:
		inventory.remove_item(mask_item.resource_name, 1)
	if inventory_slot_hud:
		inventory_slot_hud._refresh_slots()

## Update floating mask icon above player when active mask changes (64x64).
func _on_active_mask_icon_changed(texture: Texture2D, _mask_name: String) -> void:
	if not is_instance_valid(active_mask_icon):
		return
	if texture:
		active_mask_icon.texture = texture
		active_mask_icon.visible = true
	else:
		active_mask_icon.visible = false
		active_mask_icon.texture = null
