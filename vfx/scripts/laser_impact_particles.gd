@tool
class_name LaserImpactParticles
extends GPUParticles2D

## Laser Impact Spark Particles
## Creates bright spark effects when laser hits a surface.
## Continuously emits while active, call start_emission() and stop_emission().

@export_group("Spark Settings")
@export var spark_amount: int = 12 ## Number of particles per emission cycle.
@export var spark_lifetime: float = 0.3 ## How long each spark lives.
@export var spark_speed_min: float = 80.0 ## Minimum spark velocity.
@export var spark_speed_max: float = 200.0 ## Maximum spark velocity.

@export_group("Colors")
@export var spark_color: Color = Color(1.0, 0.3, 0.3, 1.0) ## Base spark color (usually laser color).
@export var spark_color_end: Color = Color(1.0, 0.8, 0.2, 0.0) ## Fades to this color (warm glow).

@export_group("Size")
@export var spark_size_start: float = 6.0 ## Initial spark size.
@export var spark_size_end: float = 1.0 ## Final spark size before fading.

@export_group("Spread")
@export var spread_angle_degrees: float = 120.0 ## Spray cone angle in degrees.
@export var spray_direction: Vector2 = Vector2.LEFT ## Direction sparks spray (opposite of laser).

var _is_emitting: bool = false


func _ready() -> void:
	# Configure for continuous emission while laser hits surface
	emitting = false
	one_shot = false
	explosiveness = 0.8 # High explosiveness for burst-like feel
	amount = spark_amount
	lifetime = spark_lifetime
	
	# Create procedural particle material
	_setup_particle_material()


func _setup_particle_material() -> void:
	var mat := ParticleProcessMaterial.new()
	
	# Direction and spread (spray away from impact)
	mat.direction = Vector3(spray_direction.x, spray_direction.y, 0.0)
	mat.spread = spread_angle_degrees / 2.0
	
	# Speed
	mat.initial_velocity_min = spark_speed_min
	mat.initial_velocity_max = spark_speed_max
	
	# Gravity - slight downward pull for sparks
	mat.gravity = Vector3(0, 150.0, 0)
	
	# Damping to slow particles naturally
	mat.damping_min = 100.0
	mat.damping_max = 200.0
	
	# Scale
	mat.scale_min = spark_size_start / 8.0
	mat.scale_max = spark_size_start / 8.0
	
	# Scale curve - shrink over lifetime
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.5, 0.7))
	scale_curve.add_point(Vector2(1.0, spark_size_end / spark_size_start))
	var scale_curve_tex := CurveTexture.new()
	scale_curve_tex.curve = scale_curve
	mat.scale_curve = scale_curve_tex
	
	# Color gradient - bright to warm glow to fade
	var gradient := Gradient.new()
	gradient.set_color(0, spark_color)
	gradient.add_point(0.3, spark_color.lightened(0.3)) # Bright flash
	gradient.add_point(1.0, spark_color_end)
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex
	
	# Emission shape (point at impact location)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	
	process_material = mat
	
	# Create glowing spark texture
	_setup_spark_texture()


func _setup_spark_texture() -> void:
	# Create a bright core with glow falloff for spark appearance
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center := Vector2(16, 16)
	
	for x in range(32):
		for y in range(32):
			var dist := Vector2(x, y).distance_to(center)
			# Sharp bright core with soft glow
			var core := clampf(1.0 - (dist / 6.0), 0.0, 1.0)
			var glow := clampf(1.0 - (dist / 14.0), 0.0, 1.0)
			glow = glow * glow # Softer falloff for glow
			var brightness := maxf(core, glow * 0.5)
			var alpha := clampf(1.0 - (dist / 16.0), 0.0, 1.0)
			img.set_pixel(x, y, Color(brightness, brightness, brightness, alpha))
	
	var tex := ImageTexture.create_from_image(img)
	texture = tex


## Set the spark color (call before or during emission).
func set_spark_color(color: Color) -> void:
	spark_color = color
	# Create warm end color based on the spark color
	spark_color_end = Color(
		minf(color.r + 0.5, 1.0),
		minf(color.g + 0.3, 1.0),
		color.b * 0.3,
		0.0
	)
	
	if process_material is ParticleProcessMaterial:
		var mat := process_material as ParticleProcessMaterial
		var gradient := Gradient.new()
		gradient.set_color(0, spark_color)
		gradient.add_point(0.3, spark_color.lightened(0.3))
		gradient.add_point(1.0, spark_color_end)
		var gradient_tex := GradientTexture1D.new()
		gradient_tex.gradient = gradient
		mat.color_ramp = gradient_tex


## Set the spray direction (direction sparks fly - usually opposite of laser direction).
func set_spray_direction(dir: Vector2) -> void:
	spray_direction = dir.normalized()
	
	if process_material is ParticleProcessMaterial:
		var mat := process_material as ParticleProcessMaterial
		mat.direction = Vector3(spray_direction.x, spray_direction.y, 0.0)


## Start continuous spark emission (call when laser hits surface).
func start_emission() -> void:
	if _is_emitting:
		return
	_is_emitting = true
	emitting = true


## Stop spark emission (call when laser stops hitting surface).
func stop_emission() -> void:
	if not _is_emitting:
		return
	_is_emitting = false
	emitting = false


## Update position to collision point.
func set_impact_position(pos: Vector2) -> void:
	global_position = pos


## Check if currently emitting.
func is_active() -> bool:
	return _is_emitting
