# Deadshift architecture

## Product direction

Deadshift is deliberately small: a portrait-mode zombie-wave survival game designed to test how far the Personal GitHub ↔ ChatGPT bridge can carry a real software project with minimal human intervention.

## Technology

- Expo SDK 57
- React Native
- TypeScript
- Pure deterministic game-state functions in `src/game.ts`
- React Native rendering/input in `App.tsx`
- Vitest for deterministic game-engine tests
- GitHub Actions for validation

No repository-local AI coding agent is used.

## V0 gameplay loop

1. Player drags anywhere on the arena to move.
2. Zombies spawn from arena edges and pursue the player.
3. The player auto-fires at the nearest zombie.
4. Kills add score.
5. Enemy contact costs health.
6. Waves increase every 20 seconds.
7. Death presents a one-tap restart.

## Design rule

Game rules stay separate from rendering so balance, progression, collision behavior, and future bridge-driven changes can be validated deterministically.
