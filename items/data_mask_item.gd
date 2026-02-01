## Resource class for mask items that can be used to apply effects.
## Extends DataItem with mask-specific functionality.
class_name DataMaskItem
extends DataItem

enum MaskType {
	NIGHT_VISION,
	DISGUISE
}

@export var mask_type: MaskType
@export var effect_duration: float = 5.0 ## Duration of the effect in seconds.
@export var mask_texture: Texture2D ## Full texture to display on player's head when active.

@export_group("Sound Effects")
@export var activate_sound: AudioStream ## Sound played when mask effect is activated.
@export var deactivate_sound: AudioStream ## Sound played when mask effect ends.