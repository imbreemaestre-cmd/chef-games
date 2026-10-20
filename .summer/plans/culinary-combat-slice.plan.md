---
name: culinary-combat-slice
overview: >-
  2D top-down pixel-art conversion of Sunberry Hollow: gather berries in a forest,
  cook Berry Compote at a campfire, and battle a wild Blackberry Tart turn-based.
createdAt: '2026-10-20T06:19:24.828Z'
todos:
  - id: m0-inspect
    content: Inspect the 3D prototype, keep the 3D scripts as *_3d.gd, and record the conversion plan.
    status: completed
  - id: m1-two-d
    content: Rebuild the forest as a true 2D top-down pixel-art scene with CharacterBody2D, Camera2D, TileMapLayer, Area2D interactions and a CanvasLayer HUD.
    status: completed
  - id: m2-loop
    content: Restore the loop - berry gathering with HUD counter, campfire cooking of Berry Compote, party join, Blackberry Tart battle, rewards and defeat handling.
    status: completed
  - id: m3-cooking-system
    content: Generalise cooking into recipe validation, equipment method checks, success probability and quality tiers instead of one hardcoded recipe.
    status: pending
  - id: m4-recipe-learning
    content: Add an NPC who teaches a recipe, a readable cookbook, the Cooking Journal, familiarity and scroll mastery, plus save/load.
    status: pending
  - id: m5-nonlinear
    content: Add a village, an accessible NPC house, a hidden deep fryer, cauliflower and the Fried Cauliflower early shortcut.
    status: pending
  - id: m6-expansion
    content: Expand content - more foods, moves, cookware, proficiency, TV cooking shows, food transformations, more areas and the Level 100 chef boss.
    status: pending
template: scratch
---
# Sunberry Hollow - 2D culinary adventure

## Permanent direction
2D top-down pixel-art RPG, 640x360 base resolution, 32 px tiles, nearest filtering.
Foods are the literal battlers (Berry Compote, Blackberry Tart, ...) with real culinary
names. No food monsters, no humanoid food, no 3D revival.

## Architecture (Godot 2D)
- `res://main.tscn` - Node2D root; World (y-sorted) holds Ground TileMapLayer + Player;
  HUD and Battle are CanvasLayers.
- `res://scripts/game.gd` - world builder (tiles, path, trees, rocks, bushes, campfire,
  tart), inventory, cooking flow, battle handoff, HUD refresh.
- `res://scripts/art.gd` - procedural pixel art (tiles atlas, chef sheet, bush, tree,
  rock, campfire frames, ring, sparkle, dish sprites, berry icon). Replace a builder with
  a real PNG later without touching gameplay.
- `res://scripts/data.gd` - ingredients, equipment + methods, recipes, moves, foods,
  flavour triangle and the single damage formula.
- `res://scripts/player.gd` - CharacterBody2D, four-direction walk/run, InteractArea.
- `res://scripts/berry_bush.gd`, `campfire.gd`, `wild_tart.gd` - interactable Area2D props
  in group `interactable` (`is_available`, `prompt_text`, `interact(game)`).
- `res://scripts/creature.gd` - the cooked dish that follows the chef in the overworld.
- `res://scripts/hud.gd` - berry counter, party line, prompt, toasts, cooking panel,
  Escape menu.
- `res://scripts/battle.gd` - 2D turn-based battle screen: cards, HP bars, four actions
  from the food's data, damage popups, win/lose/flee result.

## Rules that must not be broken
- Chef level never gates a recipe attempt.
- Only a recipe scroll gives 100% success; other attempts cap at 95%.
- Equipment access is separate from ownership.
- Cooking quality and food combat level are separate from chef level.
- Boss battles are playable, never scripted wins.

## 3D leftovers
The previous 3D build's scripts are kept as `res://scripts/*_3d.gd`. The 3D scene file was
replaced by the 2D `res://main.tscn`; 3D library assets and starter packs remain on disk
but unused.

## Next checks
- Play-test: walk, gather x3, cook at the campfire, battle the tart, win and lose paths.
- Then milestone 3 (general cooking system) before adding new content.
