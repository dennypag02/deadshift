import { describe, expect, it } from 'vitest';
import { createGame, updateGame } from './game';

describe('Deadshift game engine', () => {
  it('starts in a playable state', () => {
    const state = createGame(300, 500);
    expect(state.player.hp).toBe(100);
    expect(state.wave).toBe(1);
    expect(state.gameOver).toBe(false);
  });

  it('moves the player while keeping them inside the arena', () => {
    let state = createGame(300, 500);
    state = updateGame(state, { move: { x: 10, y: 0 } }, 10);
    expect(state.player.position.x).toBeLessThanOrEqual(300 - state.player.radius);
  });

  it('advances waves with survival time', () => {
    let state = createGame();
    state = updateGame(state, { move: { x: 0, y: 0 } }, 41);
    expect(state.wave).toBe(3);
  });

  it('spawns enemies as time advances', () => {
    let state = createGame();
    state = updateGame(state, { move: { x: 0, y: 0 } }, 2);
    expect(state.zombies.length).toBeGreaterThan(0);
  });
});
