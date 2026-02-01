extends Node2D
## Adds or removes items from an entity inventory.

const TreasureParticlesScene: PackedScene = preload("res://vfx/scenes/TreasureParticles.tscn")

@export var contents: Array[ContentItem] ## A list of items to be obtained.
@export var show_treasure_particles: bool = true ## Show gold/silver particle fountain when collected.

signal contents_got

func get_contents(params):
	var entity: CharacterEntity = params.get("entity", null)
	if !entity:
		push_warning("Entity is missing in %s" % [get_path()])
		return
	var inventory: Inventory = Globals.get_node_inventory(entity)
	if !inventory:
		push_warning("No inventory found in %s" % [entity.name])
		return
	if contents.size() == 0 or not entity:
		return
	for content in contents:
		if content.quantity > 0:
			inventory.add_item(content.item, content.quantity)
	
	# Spawn treasure particle effect
	if show_treasure_particles:
		_spawn_treasure_particles()
	
	contents_got.emit.call_deferred()


func _spawn_treasure_particles() -> void:
	var particles: TreasureParticles = TreasureParticlesScene.instantiate()
	# Add to the same parent so it stays in place
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emit_burst()
