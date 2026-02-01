## HUD component that displays 5 inventory slots at the bottom of the screen.
## Allows selection with left/right arrow keys and usage with spacebar.
class_name InventorySlotHUD
extends CanvasLayer

signal item_used(item: DataItem)

const SLOT_COUNT := 5

@onready var slots_container: HBoxContainer = $Control/MarginContainer/VBoxContainer/ToolbarRow/SlotsContainer
@onready var slot_scenes: Array[Control] = []
@onready var item_tooltip: PanelContainer = $Control/ItemTooltip
@onready var tooltip_name_label: Label = $Control/ItemTooltip/MarginContainer/VBoxContainer/ItemName
@onready var tooltip_desc_label: Label = $Control/ItemTooltip/MarginContainer/VBoxContainer/ItemDescription

var selected_slot_index: int = 0
var inventory: Inventory = null
var slot_items: Array[DataItem] = [] ## Cached item references per slot for tooltip lookup.

func _ready() -> void:
	# Ensure CanvasLayer is visible
	visible = true
	layer = 100  # High layer to ensure it's on top
	
	# Wait a frame for the scene tree to be fully ready
	await get_tree().process_frame
	
	# Ensure slots_container is ready
	if not slots_container:
		push_error("InventorySlotHUD: SlotsContainer not found!")
		return
	
	print("InventorySlotHUD: SlotsContainer found at path: %s" % slots_container.get_path())
	print("InventorySlotHUD: CanvasLayer visible: %s, layer: %d" % [visible, layer])
	
	# Initialize slot_items array
	slot_items.resize(SLOT_COUNT)
	for i in range(SLOT_COUNT):
		slot_items[i] = null
	
	# Create 5 slot UI elements
	for i in range(SLOT_COUNT):
		var slot = _create_slot(i)
		slots_container.add_child(slot)
		slot_scenes.append(slot)
	
	# Wait another frame for layout to update
	await get_tree().process_frame
	
	_update_slot_selection()
	print("InventorySlotHUD: Created %d slots" % slot_scenes.size())
	print("InventorySlotHUD: SlotsContainer size: %s, position: %s, visible: %s" % [slots_container.size, slots_container.position, slots_container.visible])
	var margin_container = get_node_or_null("Control/MarginContainer")
	if margin_container:
		print("InventorySlotHUD: MarginContainer size: %s, position: %s, visible: %s" % [margin_container.size, margin_container.position, margin_container.visible])
	if slot_scenes.size() > 0:
		print("InventorySlotHUD: First slot size: %s, position: %s, visible: %s" % [slot_scenes[0].size, slot_scenes[0].position, slot_scenes[0].visible])
		var first_panel = slot_scenes[0].get_node_or_null("Background")
		if first_panel:
			print("InventorySlotHUD: First panel size: %s, visible: %s, modulate: %s" % [first_panel.size, first_panel.visible, first_panel.modulate])
	
	# Refresh slots now that they're created (in case inventory was set before slots existed)
	if inventory:
		print("InventorySlotHUD: Inventory already set, refreshing slots...")
		_refresh_slots()

func _input(event: InputEvent) -> void:
	if not inventory:
		return
	
	# Only handle key events
	if not event is InputEventKey or not event.pressed:
		return
	
	# Handle slot selection with Q (left) and E (right)
	if event.keycode == KEY_Q:
		var old_index = selected_slot_index
		selected_slot_index = max(0, selected_slot_index - 1)
		if selected_slot_index != old_index:
			AudioManager.play_sfx("inventory_select")
		_update_slot_selection()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_E:
		var old_index = selected_slot_index
		selected_slot_index = min(SLOT_COUNT - 1, selected_slot_index + 1)
		if selected_slot_index != old_index:
			AudioManager.play_sfx("inventory_select")
		_update_slot_selection()
		get_viewport().set_input_as_handled()
	# Handle item usage (spacebar)
	elif event.keycode == KEY_SPACE:
		_use_selected_item()
		get_viewport().set_input_as_handled()

## Set the inventory to display.
func set_inventory(inv: Inventory) -> void:
	inventory = inv
	print("InventorySlotHUD: Inventory set, items count: %d" % (inv.items.size() if inv else 0))
	_refresh_slots()
	
	# Connect to inventory updates if possible
	# Note: Inventory doesn't have signals for changes, so we'll refresh on item use

## Refresh all slots with current inventory contents.
func _refresh_slots() -> void:
	if not inventory:
		print("InventorySlotHUD: No inventory to refresh")
		return
	
	if slot_scenes.is_empty():
		print("InventorySlotHUD: No slots created yet")
		return
	
	# Clear all slots and slot_items first
	for i in range(SLOT_COUNT):
		if i < slot_items.size():
			slot_items[i] = null
		var slot = slot_scenes[i]
		var icon = slot.get_node_or_null("ItemIcon")
		var label = slot.get_node_or_null("QuantityLabel")
		if icon:
			icon.texture = null
		if label:
			label.text = ""
			label.visible = false
	
	# Fill slots with inventory items (up to 5)
	var items = inventory.items
	print("InventorySlotHUD: Refreshing %d items into slots" % items.size())
	for i in range(min(items.size(), SLOT_COUNT)):
		var content_item: ContentItem = items[i]
		if content_item and content_item.item:
			# Cache item reference for tooltip
			slot_items[i] = content_item.item
			
			var slot = slot_scenes[i]
			var icon = slot.get_node_or_null("ItemIcon")
			var label = slot.get_node_or_null("QuantityLabel")
			if icon:
				icon.texture = content_item.item.icon
				icon.visible = true
				print("InventorySlotHUD: Slot %d icon set, texture: %s, visible: %s" % [i, icon.texture, icon.visible])
			if label:
				label.text = str(content_item.quantity)
				label.visible = true  # Always show quantity
			print("InventorySlotHUD: Slot %d filled with %s x%d" % [i, content_item.item.resource_name, content_item.quantity])
	
	# Update tooltip for current selection
	_update_selected_tooltip()

## Create a single slot UI element.
func _create_slot(index: int) -> Control:
	var slot = Control.new()
	slot.name = "Slot%d" % index
	slot.custom_minimum_size = Vector2(64, 64)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.visible = true
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Background panel
	var panel = Panel.new()
	panel.name = "Background"
	slot.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Make panel very visible with bright colors for debugging
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.3, 0.3, 0.3, 1.0)  # More opaque
	style_box.border_color = Color(1.0, 1.0, 1.0, 1.0)  # White border
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	panel.add_theme_stylebox_override("panel", style_box)
	panel.visible = true
	
	# Selection glow (initially hidden)
	var glow = ColorRect.new()
	glow.name = "SelectionGlow"
	glow.color = Color(0.5, 0.8, 1.0, 0.5)  # Light blue glow
	glow.visible = false
	slot.add_child(glow)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Item icon
	var icon = TextureRect.new()
	icon.name = "ItemIcon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8.0
	icon.offset_top = 8.0
	icon.offset_right = -8.0
	icon.offset_bottom = -24.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Quantity label
	var quantity_label = Label.new()
	quantity_label.name = "QuantityLabel"
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	slot.add_child(quantity_label)
	quantity_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quantity_label.offset_left = 4.0
	quantity_label.offset_top = 4.0
	quantity_label.offset_right = -4.0
	quantity_label.offset_bottom = -4.0
	quantity_label.add_theme_color_override("font_color", Color.WHITE)
	quantity_label.add_theme_color_override("font_outline_color", Color.BLACK)
	quantity_label.add_theme_constant_override("outline_size", 2)
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	return slot

## Update which slot is highlighted and update tooltip for selected item.
func _update_slot_selection() -> void:
	for i in range(slot_scenes.size()):
		var slot = slot_scenes[i]
		var glow = slot.get_node_or_null("SelectionGlow")
		if glow:
			glow.visible = (i == selected_slot_index)
	
	# Update tooltip for selected slot
	_update_selected_tooltip()

## Use the currently selected item.
func _use_selected_item() -> void:
	if not inventory or inventory.items.is_empty():
		return
	
	if selected_slot_index >= inventory.items.size():
		return
	
	var content_item: ContentItem = inventory.items[selected_slot_index]
	if not content_item or content_item.quantity <= 0:
		return
	
	# Play item use sound
	AudioManager.play_sfx("item_use")
	
	# Emit signal for item usage (handled by player entity)
	item_used.emit(content_item.item)
	
	# Consume one quantity
	inventory.remove_item(content_item.item.resource_name, 1)
	
	# Refresh display
	_refresh_slots()

## Update tooltip to show info for currently selected slot.
func _update_selected_tooltip() -> void:
	if selected_slot_index < 0 or selected_slot_index >= slot_items.size():
		if item_tooltip:
			item_tooltip.visible = false
		return
	
	var item = slot_items[selected_slot_index]
	if not item:
		# No item in selected slot, hide tooltip
		if item_tooltip:
			item_tooltip.visible = false
		return
	
	# Update tooltip content
	if tooltip_name_label:
		tooltip_name_label.text = item.resource_name
	if tooltip_desc_label:
		tooltip_desc_label.text = item.description if item.description else ""
	
	# Show tooltip
	if item_tooltip:
		item_tooltip.visible = true
