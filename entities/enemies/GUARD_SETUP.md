# Guard Setup Guide

## Prerequisites

### 1. Guard Scene Uses Entity Base ✓
The guard scene (`entities/enemies/guard.tscn`) instances `entity.tscn` as its base, inheriting:
- Character animations and sprite setup
- Health system
- Movement and collision
- All entity functionality

### 2. Navigation Setup Required
**IMPORTANT**: Your level must have a `NavigationRegion2D` node with a navigation mesh for guards to pathfind.

**Setup Steps:**
1. Add a `NavigationRegion2D` node to your level scene
2. Add `NavigationAgent2D` nodes will automatically use the nearest NavigationRegion2D
3. The navigation mesh will be generated/baked from your level geometry

**Note**: The guard's `NavigationAgent2D` is already configured and will automatically connect to the NavigationRegion2D when the level loads.

### 3. Player in Vision Target Group ✓
The player is already added to the `"vision_target"` group in `entities/player/player.tscn`, so guards can detect it.

### 4. Collision Layers for LOS Blocking ✓
**Collision Layer Configuration:**
- **Layer 1** = `"block"` (walls/obstacles that block line of sight)
- The guard's `VisionConeSensor` has `los_blocking_collision_mask = 1` which correctly checks layer 1

**To ensure walls block LOS:**
- Make sure your wall TileMapLayers or StaticBody2D nodes have `collision_layer = 1` (or include bit 1)
- This is the default "block" layer in your project settings

## Guard Configuration

### Exported Variables (in Guard scene):
- `chase_speed`: Speed when chasing (default: 200.0)
- `patrol_speed`: Speed when patrolling (default: 100.0)
- `forget_time`: Seconds after losing LOS before giving up chase (default: 3.0)
- `investigate_time`: Seconds to linger at last seen position (default: 2.0)
- `patrol_points`: Array of NodePaths to patrol waypoints (empty = sentry mode)
- `pause_at_waypoint`: Seconds to wait at each patrol point (default: 1.0)
- `patrol_loop`: If true, loops patrol; if false, ping-pongs (default: true)
- `home_position`: Position to return to (auto-set to spawn position)
- `home_facing`: Direction to face when at home (default: DOWN)

### Perception Settings (in Perception node):
- `scan_rate_hz`: How many times per second to scan (default: 10.0)
- `target_group`: Group name for detectable targets (`"vision_target"`)
- `los_blocking_collision_mask`: Physics layers that block LOS (default: 1 = "block" layer)
- `cone_profile`: Cone parameters (range, FOV, origin offset)

## Usage

1. **Add Guard to Level:**
   - Instance `entities/enemies/guard.tscn` in your level scene
   - Position it where you want the guard to spawn

2. **Configure Patrol (Optional):**
   - Add `Marker2D` nodes as patrol waypoints
   - Set their NodePaths in the guard's `patrol_points` array
   - If no patrol points, guard will be a stationary sentry

3. **Set Initial State:**
   - Default: `sentry` (stationary)
   - Change `current_state` in GuardStates to `patrol` if you want patrol mode

4. **Test:**
   - Run the game
   - Move player into guard's FOV cone
   - Guard should spot player and chase
   - Break LOS to test investigate/return behavior

## Debug Drawing

To enable debug visualization:
1. Add `GuardDebugDraw` component as child of Guard
2. Set `enabled = true`
3. Configure colors and what to draw (FOV cone, LOS rays, nav path)
