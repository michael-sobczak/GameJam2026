# Heist Masquerade

A stealth heist game where cunning and magical masks are your greatest tools. Slip past guards, manipulate shadows, and pull off the perfect heist.

### Built With

[![Godot Engine](https://img.shields.io/badge/Godot_4.6-blue?logo=godotengine&logoColor=white)](https://godotengine.org)

## 🎭 About the Game

In **Heist Masquerade**, you play as a master thief who has acquired a collection of enchanted masks, each granting unique abilities. Navigate through heavily guarded locations, avoid detection, and complete your objectives using stealth, timing, and the magical powers of your masks.

## 🎮 Controls

| Action | Key |
|--------|-----|
| Move | W, A, S, D |
| Toggle Flashlight | F |
| Scroll Items Left | Q |
| Scroll Items Right | E |
| Use Selected Item | Spacebar |

## ⚙️ Game Mechanics

### 🔦 Flashlight

Your flashlight illuminates dark areas, helping you navigate through shadowy environments. However, be careful—light can also give away your position to watchful guards. Toggle it wisely.

### 👁️ Guard Vision

Guards patrol the area with keen eyes. Their vision cones represent their field of view. Stay out of sight, use cover, and time your movements to slip past undetected. If spotted, guards will pursue you.

### 🎭 Masks

Masks are your secret weapons. Each mask grants a temporary magical ability when activated:

| Mask | Effect |
|------|--------|
| **Night Vision Mask** | See clearly in the dark for a short time, revealing hidden paths and dangers without using your flashlight. |
| **Disguise Mask** | Blend in with enemies and avoid detection, allowing you to walk past guards unnoticed. |

Masks have limited uses, so use them strategically!

### 🎒 Inventory

Your inventory displays up to 5 items at the bottom of the screen. Use **Q** and **E** to cycle through your items, and press **Spacebar** to activate the selected mask.

## 🏆 Objectives

- Infiltrate guarded locations
- Avoid detection by guards
- Use your masks and flashlight strategically
- Complete each heist without getting caught

## 🚀 Getting Started

1. Clone this repository
2. Open the project in Godot 4.6+
3. Run the main scene to start playing

## 📁 Project Structure

```
├── assets/          # Art, audio, fonts, and shaders
├── components/      # Reusable game components (inventory, flashlight, etc.)
├── entities/        # Player, enemies, and NPCs
├── items/           # Item definitions and resources
├── scenes/          # Game scenes, levels, menus, and props
├── scripts/         # Core systems, autoloads, and utilities
├── shaders/         # Visual effect shaders
└── tilesets/        # Tilemap resources
```

## 🎨 Credits

- Game developed for **Game Jam 2026**
- Built using the [Godot 2D Top-Down Template](https://github.com/stesproject/godot-2d-topdown-template) as a foundation

---

*Stay in the shadows. Trust your masks. Pull off the perfect heist.*
