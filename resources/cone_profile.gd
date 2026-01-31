## Resource that defines cone parameters shared between visual flashlight and vision detection.
## Ensures flashlight appearance matches NPC vision detection range/FOV.
class_name ConeProfile
extends Resource

@export var range_px: float = 300.0 ## Maximum range of the cone in pixels.
@export var fov_degrees: float = 60.0 ## Field of view angle in degrees.
@export var origin_offset: Vector2 = Vector2.ZERO ## Offset from character center where cone originates.
