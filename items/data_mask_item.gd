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
