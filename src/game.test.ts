import { describe,expect,it } from 'vitest';import { createGame,updateGame } from './game';
describe('Deadshift vertical slice engine',()=>{
 it('starts armed and playable',()=>{const s=createGame(300,500);expect(s.player.hp).toBe(100);expect(s.player.ammo).toBe(90);expect(s.gameOver).toBe(false)});
 it('keeps movement in arena',()=>{const s=updateGame(createGame(300,500),{move:{x:10,y:0}},10);expect(s.player.position.x).toBeLessThanOrEqual(300-s.player.radius)});
 it('advances waves',()=>{const s=updateGame(createGame(),{move:{x:0,y:0}},41);expect(s.wave).toBe(3)});
 it('spawns enemies',()=>{const s=updateGame(createGame(),{move:{x:0,y:0}},2);expect(s.zombies.length).toBeGreaterThan(0)});
 it('sprinting spends stamina',()=>{const s=updateGame(createGame(),{move:{x:1,y:0},sprint:true},.5);expect(s.player.stamina).toBeLessThan(100)});
 it('dodge grants temporary invulnerability',()=>{const s=updateGame(createGame(),{move:{x:1,y:0},dodge:true},.05);expect(s.player.invulnerable).toBeGreaterThan(0);expect(s.player.dodgeCooldown).toBeGreaterThan(0)});
 it('brute arrives by wave five',()=>{const s=updateGame(createGame(),{move:{x:0,y:0}},81);expect(s.bossSpawned).toBe(true);expect(s.zombies.some(z=>z.kind==='brute')).toBe(true)});
});
