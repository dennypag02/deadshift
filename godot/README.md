# Deadshift V3 — Godot scrolling-world vertical slice

This is an **independent V3 development track**. The V2 React Native / Expo application and its working Android APK remain unchanged on main.

## What this implements

- Godot 4 native 2D renderer, camera following the player and a world-coordinate simulation.
- Deterministic 512-pixel procedural world chunks, drawn only near the player.
- Touch-drag movement, keyboard movement for desktop testing, auto-fire, enemy spawning, wave escalation, health and score.
- Visual build identity: `DEADSHIFT V3` appears in the HUD.

## What is not yet complete

This vertical slice is **not V3A–V3E acceptance**. The colored vector placeholders are intentionally temporary. Detailed original art, animation, full V2 feature parity, automated Android packaging, and actual on-device visual/performance validation remain gates.

## Verification

Open `godot/project.godot` with Godot 4.3+ and run the main scene. In a headless CI environment, run:

```sh
godot --headless --path godot --editor --quit
```

Do not replace the known-good V2 APK until a V3 Android build is validated.
