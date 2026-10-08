export type Vec = { x: number; y: number };

export type Zombie = {
  id: number;
  position: Vec;
  hp: number;
  speed: number;
};

export type GameState = {
  width: number;
  height: number;
  player: {
    position: Vec;
    hp: number;
    radius: number;
  };
  zombies: Zombie[];
  bullets: Array<{ id: number; position: Vec; velocity: Vec; ttl: number }>;
  score: number;
  wave: number;
  elapsed: number;
  spawnClock: number;
  fireClock: number;
  nextId: number;
  gameOver: boolean;
};

export type InputState = {
  move: Vec;
};

export const DEFAULT_WIDTH = 360;
export const DEFAULT_HEIGHT = 640;

export function createGame(width = DEFAULT_WIDTH, height = DEFAULT_HEIGHT): GameState {
  return {
    width,
    height,
    player: {
      position: { x: width / 2, y: height * 0.62 },
      hp: 100,
      radius: 16,
    },
    zombies: [],
    bullets: [],
    score: 0,
    wave: 1,
    elapsed: 0,
    spawnClock: 0,
    fireClock: 0,
    nextId: 1,
    gameOver: false,
  };
}

function distance(a: Vec, b: Vec) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

function normalize(v: Vec): Vec {
  const len = Math.hypot(v.x, v.y);
  if (len < 0.0001) return { x: 0, y: 0 };
  return { x: v.x / len, y: v.y / len };
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function spawnZombie(state: GameState): Zombie {
  const side = state.nextId % 4;
  const margin = 24;
  let position: Vec;

  if (side === 0) position = { x: margin, y: (state.nextId * 83) % state.height };
  else if (side === 1) position = { x: state.width - margin, y: (state.nextId * 97) % state.height };
  else if (side === 2) position = { x: (state.nextId * 71) % state.width, y: margin };
  else position = { x: (state.nextId * 61) % state.width, y: state.height - margin };

  return {
    id: state.nextId,
    position,
    hp: 1 + Math.floor((state.wave - 1) / 3),
    speed: 26 + state.wave * 2,
  };
}

export function updateGame(state: GameState, input: InputState, dt: number): GameState {
  if (state.gameOver || dt <= 0) return state;

  const next: GameState = {
    ...state,
    player: { ...state.player, position: { ...state.player.position } },
    zombies: state.zombies.map((z) => ({ ...z, position: { ...z.position } })),
    bullets: state.bullets.map((b) => ({
      ...b,
      position: { ...b.position },
      velocity: { ...b.velocity },
    })),
  };

  next.elapsed += dt;
  next.wave = 1 + Math.floor(next.elapsed / 20);

  const move = normalize(input.move);
  const playerSpeed = 150;
  next.player.position.x = clamp(
    next.player.position.x + move.x * playerSpeed * dt,
    next.player.radius,
    next.width - next.player.radius,
  );
  next.player.position.y = clamp(
    next.player.position.y + move.y * playerSpeed * dt,
    next.player.radius,
    next.height - next.player.radius,
  );

  next.spawnClock += dt;
  const spawnInterval = Math.max(0.32, 1.15 - next.wave * 0.07);
  while (next.spawnClock >= spawnInterval) {
    next.spawnClock -= spawnInterval;
    next.zombies.push(spawnZombie(next));
    next.nextId += 1;
  }

  for (const zombie of next.zombies) {
    const dir = normalize({
      x: next.player.position.x - zombie.position.x,
      y: next.player.position.y - zombie.position.y,
    });
    zombie.position.x += dir.x * zombie.speed * dt;
    zombie.position.y += dir.y * zombie.speed * dt;
  }

  next.fireClock += dt;
  const fireInterval = 0.34;
  if (next.fireClock >= fireInterval && next.zombies.length > 0) {
    next.fireClock %= fireInterval;
    let target = next.zombies[0]!;
    for (const zombie of next.zombies) {
      if (distance(zombie.position, next.player.position) < distance(target.position, next.player.position)) {
        target = zombie;
      }
    }
    const dir = normalize({
      x: target.position.x - next.player.position.x,
      y: target.position.y - next.player.position.y,
    });
    next.bullets.push({
      id: next.nextId++,
      position: { ...next.player.position },
      velocity: { x: dir.x * 340, y: dir.y * 340 },
      ttl: 1.5,
    });
  }

  for (const bullet of next.bullets) {
    bullet.position.x += bullet.velocity.x * dt;
    bullet.position.y += bullet.velocity.y * dt;
    bullet.ttl -= dt;
  }

  const deadZombieIds = new Set<number>();
  const deadBulletIds = new Set<number>();

  for (const bullet of next.bullets) {
    if (bullet.ttl <= 0) {
      deadBulletIds.add(bullet.id);
      continue;
    }
    for (const zombie of next.zombies) {
      if (deadZombieIds.has(zombie.id)) continue;
      if (distance(bullet.position, zombie.position) <= 17) {
        zombie.hp -= 1;
        deadBulletIds.add(bullet.id);
        if (zombie.hp <= 0) {
          deadZombieIds.add(zombie.id);
          next.score += 10;
        }
        break;
      }
    }
  }

  for (const zombie of next.zombies) {
    if (deadZombieIds.has(zombie.id)) continue;
    if (distance(zombie.position, next.player.position) <= next.player.radius + 14) {
      deadZombieIds.add(zombie.id);
      next.player.hp -= 18;
    }
  }

  next.zombies = next.zombies.filter((z) => !deadZombieIds.has(z.id));
  next.bullets = next.bullets.filter((b) => !deadBulletIds.has(b.id) && b.ttl > 0);

  if (next.player.hp <= 0) {
    next.player.hp = 0;
    next.gameOver = true;
  }

  return next;
}
