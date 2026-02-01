# Game Jam VFX Pack

A cohesive, low-asset visual effects pack for Godot 4.x. Designed for game jams: minimal files, clear structure, good defaults.

## Quick Start

1. Open the project in Godot 4.x
2. Run `res://demo/DemoMain.tscn`
3. Use keyboard/mouse to interact with effects

## Demo Controls

| Key | Action |
|-----|--------|
| `1` | Toggle Noise Overlay |
| `2` | Toggle Screen Distortion |
| `3` | Toggle Text Wave Effects |
| `4` | Toggle Glitch Text |
| `5` | Toggle SDF Shapes |
| `Space` | Trigger Particle Burst |
| `Click` | Trigger Shockwave at mouse position |
| `Esc` | Quit demo |

## File Structure

```
res://vfx/
├── shaders/
│   ├── noise_overlay.gdshader    # Animated noise background/overlay
│   ├── text_wave.gdshader        # Wave distortion + color cycling for text
│   ├── text_glitch.gdshader      # Glitch/corruption effect for text
│   ├── sdf_shapes.gdshader       # Procedural SDF circles, rings, rounded rects
│   └── screen_distort.gdshader   # Screen-space distortion + shockwave
├── scripts/
│   ├── impact_particles.gd       # Burst particle controller
│   ├── screen_distort_controller.gd  # Shockwave trigger + settings
│   ├── ui_motion.gd              # Procedural hover/click animations
│   └── text_glitch_controller.gd # Glitch effect controller
├── scenes/
│   └── ImpactParticles.tscn      # Ready-to-use particle scene
└── README.md

res://demo/
├── DemoMain.tscn                 # Main demo scene
└── demo_controller.gd            # Demo manager script
```

## Effects Reference

### 1. Noise Overlay (`noise_overlay.gdshader`)

Animated procedural noise with gradient coloring. Apply to `ColorRect`.

**Key Uniforms:**
| Uniform | Type | Description |
|---------|------|-------------|
| `color_a`, `color_b`, `color_c` | Color | Gradient colors |
| `use_three_colors` | bool | Use 2 or 3 color gradient |
| `noise_scale` | float | Scale of noise pattern (1-50) |
| `speed` | float | Animation speed (0-5) |
| `contrast` | float | Noise contrast (0.1-3) |
| `opacity` | float | Overall opacity (0-1) |
| `output_dissolve_mask` | bool | Output mask for dissolve effects |

### 2. Text Wave (`text_wave.gdshader`)

Wave distortion with optional rainbow color cycling. Apply to `Label` or `RichTextLabel`.

**Key Uniforms:**
| Uniform | Type | Description |
|---------|------|-------------|
| `wave_intensity` | float | Wave amplitude (0-20) |
| `wave_speed` | float | Animation speed (0-10) |
| `wave_frequency` | float | Wave frequency (0.1-20) |
| `vertical_wave` | bool | Enable vertical displacement |
| `horizontal_wave` | bool | Enable horizontal displacement |
| `enable_rainbow` | bool | Rainbow color cycling |
| `rainbow_speed` | float | Color cycle speed |
| `enable_dissolve` | bool | Dissolve edge effect |
| `dissolve_progress` | float | Dissolve amount (0-1) |

### 3. Text Glitch (`text_glitch.gdshader`)

Cyberpunk-style glitch effect with jitter, scanlines, and RGB split.

**Key Uniforms:**
| Uniform | Type | Description |
|---------|------|-------------|
| `enable_glitch` | bool | Master toggle |
| `glitch_intensity` | float | Overall intensity (0-1) |
| `glitch_frequency` | float | How often glitches occur (0.1-10) |
| `enable_jitter` | bool | Position jitter |
| `enable_scanlines` | bool | Scanline slice offset |
| `enable_rgb_split` | bool | RGB channel separation |
| `glitch_color_1`, `glitch_color_2` | Color | Flash colors |

**Controller Script (`text_glitch_controller.gd`):**
```gdscript
# Trigger one-shot glitch
$GlitchController.trigger_glitch(0.3)

# Enable auto-glitch mode
$GlitchController.set_auto_glitch(true)

# Adjust intensity
$GlitchController.set_glitch_intensity(0.8)
```

### 4. SDF Shapes (`sdf_shapes.gdshader`)

Procedural vector shapes for HUD elements. Apply to `ColorRect`.

**Key Uniforms:**
| Uniform | Type | Description |
|---------|------|-------------|
| `shape_type` | int | 0=circle, 1=ring, 2=rounded_rect |
| `size` | float | Shape size (0.1-1) |
| `ring_thickness` | float | Ring width (for ring shape) |
| `corner_radius` | float | Corner radius (for rounded rect) |
| `rect_size` | Vector2 | Rectangle dimensions |
| `fill_color` | Color | Fill color |
| `outline_color` | Color | Outline color |
| `outline_width` | float | Outline thickness |
| `enable_pulse` | bool | Animated pulse |
| `pulse_speed`, `pulse_intensity` | float | Pulse animation |
| `rotation_speed` | float | Continuous rotation |
| `show_crosshair` | bool | Add crosshair overlay |
| `show_radar_lines` | bool | Add radar-style lines |

### 5. Screen Distortion (`screen_distort.gdshader`)

Full-screen post-process distortion. Apply to full-screen `ColorRect`.

**Key Uniforms:**
| Uniform | Type | Description |
|---------|------|-------------|
| `enable_noise_distort` | bool | Noise-based wobble |
| `noise_strength` | float | Distortion amount (0-0.1) |
| `noise_scale` | float | Noise pattern scale |
| `enable_shockwave` | bool | Shockwave effect |
| `shockwave_center` | Vector2 | Shockwave origin (UV coords) |
| `shockwave_radius` | float | Current radius |
| `shockwave_strength` | float | Distortion strength |
| `enable_heat_haze` | bool | Heat shimmer effect |
| `enable_chromatic` | bool | Chromatic aberration |

**Controller Script (`screen_distort_controller.gd`):**
```gdscript
# Trigger shockwave at mouse position
$ScreenDistort.trigger_shockwave_at_mouse()

# Trigger at specific UV coords
$ScreenDistort.trigger_shockwave_uv(Vector2(0.5, 0.5))

# Trigger at screen position
$ScreenDistort.trigger_shockwave_screen(get_viewport().get_mouse_position())

# Toggle effects
$ScreenDistort.set_noise_distort(true)
$ScreenDistort.set_chromatic(true)
```

### 6. Impact Particles (`impact_particles.gd`)

Procedural burst particles for hits, magic, explosions.

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `burst_amount` | int | Particles per burst |
| `burst_lifetime` | float | Particle lifetime |
| `burst_speed_min/max` | float | Speed range |
| `color_start`, `color_end` | Color | Gradient colors |
| `size_start`, `size_end` | float | Size over lifetime |
| `spread_angle` | float | Emission cone (360 = full circle) |

**Usage:**
```gdscript
# Emit at current position
$ImpactParticles.emit_burst()

# Emit at specific position
$ImpactParticles.emit_burst_at(Vector2(500, 300))

# Change colors
$ImpactParticles.set_colors(Color.CYAN, Color.TRANSPARENT)
```

### 7. UI Motion (`ui_motion.gd`)

Procedural animations for UI elements. Attach to any `Control` node.

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `enable_breathing` | bool | Idle scale animation |
| `breathing_scale_amount` | float | Breath intensity |
| `breathing_speed` | float | Breath speed |
| `enable_hover_wobble` | bool | Wobble on mouse hover |
| `wobble_rotation_amount` | float | Rotation wobble (degrees) |
| `wobble_offset_amount` | float | Position wobble (pixels) |
| `enable_click_punch` | bool | Scale punch on click |
| `punch_scale` | float | Punch scale (0.9 = 10% smaller) |

**Usage:**
```gdscript
# Trigger punch manually
$Button.trigger_punch()

# Disable all motion
$Button.set_motion_enabled(false)

# Reset to base transform
$Button.reset_transform()
```

## Theming / Palette

All shaders expose color parameters as uniforms. The default palette is:

- **Teal**: `Color(0.1, 0.8, 0.9)` - Primary accent
- **Purple**: `Color(0.6, 0.2, 0.8)` - Secondary
- **Pink**: `Color(0.9, 0.3, 0.6)` - Highlight/Energy
- **Dark**: `Color(0.05, 0.05, 0.1)` - Background

To change the theme, update shader uniforms:

```gdscript
# Example: Switch to red/orange theme
var mat = $NoiseOverlay.material as ShaderMaterial
mat.set_shader_parameter("color_a", Color.DARK_RED)
mat.set_shader_parameter("color_b", Color.ORANGE_RED)
mat.set_shader_parameter("color_c", Color.YELLOW)
```

## Performance Notes

- All shaders use cheap value noise (not Perlin/Simplex)
- FBM limited to 3 octaves for performance
- Particles are procedurally textured (no sprite sheets)
- Screen distortion samples screen texture once (or 3x for chromatic)

## Integration Tips

1. **Copy what you need** - Each shader/script works independently
2. **Combine effects** - Layer noise overlay + screen distort + particles
3. **Use signals** - Particles and shockwave emit `*_started`/`*_finished` signals
4. **Tune uniforms** - Start subtle, increase for impact moments

## License

MIT - Use freely in your game jam projects!
