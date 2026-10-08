export type Vec = { x: number; y: number };
export type ZombieKind = 'basic' | 'runner' | 'heavy' | 'brute';
export type PickupKind = 'ammo' | 'health' | 'grenade' | 'drone';

export type Zombie = { id:number; position:Vec; hp:number; maxHp:number; speed:number; radius:number; kind:ZombieKind; damage:number };
export type Pickup = { id:number; position:Vec; kind:PickupKind };
export type GameState = {
  width:number; height:number;
  player:{ position:Vec; hp:number; radius:number; ammo:number; grenades:number; stamina:number; dodgeCooldown:number; invulnerable:number };
  zombies:Zombie[]; bullets:Array<{id:number;position:Vec;velocity:Vec;ttl:number;damage:number}>;
  pickups:Pickup[]; score:number; kills:number; wave:number; elapsed:number; spawnClock:number; fireClock:number; pickupClock:number; nextId:number;
  droneCharges:number; droneFlash:number; bossSpawned:boolean; bossDefeated:boolean; gameOver:boolean;
};
export type InputState={ move:Vec; sprint?:boolean; dodge?:boolean; grenade?:boolean; drone?:boolean };
export const DEFAULT_WIDTH=360, DEFAULT_HEIGHT=640;
const dist=(a:Vec,b:Vec)=>Math.hypot(a.x-b.x,a.y-b.y);
const norm=(v:Vec):Vec=>{const l=Math.hypot(v.x,v.y);return l<.0001?{x:0,y:0}:{x:v.x/l,y:v.y/l}};
const clamp=(v:number,a:number,b:number)=>Math.max(a,Math.min(b,v));

export function createGame(width=DEFAULT_WIDTH,height=DEFAULT_HEIGHT):GameState{
 return {width,height,player:{position:{x:width/2,y:height*.62},hp:100,radius:17,ammo:90,grenades:2,stamina:100,dodgeCooldown:0,invulnerable:0},
 zombies:[],bullets:[],pickups:[],score:0,kills:0,wave:1,elapsed:0,spawnClock:0,fireClock:0,pickupClock:0,nextId:1,droneCharges:0,droneFlash:0,bossSpawned:false,bossDefeated:false,gameOver:false};
}
function spawnZombie(s:GameState,kind?:ZombieKind):Zombie{
 const side=s.nextId%4,m=24; let p:Vec;
 if(side===0)p={x:m,y:(s.nextId*83)%s.height}; else if(side===1)p={x:s.width-m,y:(s.nextId*97)%s.height}; else if(side===2)p={x:(s.nextId*71)%s.width,y:m}; else p={x:(s.nextId*61)%s.width,y:s.height-m};
 const k=kind??(s.wave>=4&&s.nextId%9===0?'heavy':s.wave>=2&&s.nextId%5===0?'runner':'basic');
 const cfg=k==='brute'?{hp:45,speed:34,radius:30,damage:34}:k==='heavy'?{hp:5,speed:24,radius:20,damage:24}:k==='runner'?{hp:1,speed:58,radius:13,damage:14}:{hp:2,speed:32+s.wave*2,radius:15,damage:18};
 return {id:s.nextId,position:p,hp:cfg.hp,maxHp:cfg.hp,speed:cfg.speed,radius:cfg.radius,kind:k,damage:cfg.damage};
}
function addPickup(s:GameState){
 const kinds:PickupKind[]=['ammo','health','grenade','drone']; const kind=kinds[s.nextId%kinds.length]!;
 s.pickups.push({id:s.nextId++,kind,position:{x:45+(s.nextId*73)%(s.width-90),y:80+(s.nextId*91)%(s.height-160)}});
}
export function updateGame(state:GameState,input:InputState,dt:number):GameState{
 if(state.gameOver||dt<=0)return state;
 const n:GameState={...state,player:{...state.player,position:{...state.player.position}},zombies:state.zombies.map(z=>({...z,position:{...z.position}})),bullets:state.bullets.map(b=>({...b,position:{...b.position},velocity:{...b.velocity}})),pickups:state.pickups.map(p=>({...p,position:{...p.position}}))};
 n.elapsed+=dt;n.wave=1+Math.floor(n.elapsed/20);n.player.dodgeCooldown=Math.max(0,n.player.dodgeCooldown-dt);n.player.invulnerable=Math.max(0,n.player.invulnerable-dt);n.droneFlash=Math.max(0,n.droneFlash-dt);
 const move=norm(input.move); const sprint=!!input.sprint&&n.player.stamina>0&&Math.hypot(move.x,move.y)>0;
 n.player.stamina=clamp(n.player.stamina+(sprint?-34:22)*dt,0,100); let speed=sprint?225:150;
 if(input.dodge&&n.player.dodgeCooldown<=0&&Math.hypot(move.x,move.y)>0){speed=430;n.player.dodgeCooldown=1.5;n.player.invulnerable=.35;}
 n.player.position.x=clamp(n.player.position.x+move.x*speed*dt,n.player.radius,n.width-n.player.radius);n.player.position.y=clamp(n.player.position.y+move.y*speed*dt,n.player.radius,n.height-n.player.radius);
 n.spawnClock+=dt;const interval=Math.max(.28,1.08-n.wave*.075);while(n.spawnClock>=interval){n.spawnClock-=interval;n.zombies.push(spawnZombie(n));n.nextId++;}
 if(n.wave>=5&&!n.bossSpawned){n.zombies.push(spawnZombie(n,'brute'));n.nextId++;n.bossSpawned=true;}
 n.pickupClock+=dt;if(n.pickupClock>=12){n.pickupClock=0;addPickup(n);}
 for(const z of n.zombies){const d=norm({x:n.player.position.x-z.position.x,y:n.player.position.y-z.position.y});z.position.x+=d.x*z.speed*dt;z.position.y+=d.y*z.speed*dt;}
 n.fireClock+=dt;if(n.fireClock>=.27&&n.zombies.length&&n.player.ammo>0){n.fireClock%=.27;let t=n.zombies[0]!;for(const z of n.zombies)if(dist(z.position,n.player.position)<dist(t.position,n.player.position))t=z;const d=norm({x:t.position.x-n.player.position.x,y:t.position.y-n.player.position.y});n.bullets.push({id:n.nextId++,position:{...n.player.position},velocity:{x:d.x*390,y:d.y*390},ttl:1.4,damage:1});n.player.ammo--;}
 if(input.grenade&&n.player.grenades>0){n.player.grenades--;for(const z of n.zombies)if(dist(z.position,n.player.position)<125)z.hp-=6;}
 if(input.drone&&n.droneCharges>0){n.droneCharges--;n.droneFlash=.45;for(const z of n.zombies)z.hp-=12;}
 for(const b of n.bullets){b.position.x+=b.velocity.x*dt;b.position.y+=b.velocity.y*dt;b.ttl-=dt;}
 const dz=new Set<number>(),db=new Set<number>();
 for(const b of n.bullets){if(b.ttl<=0){db.add(b.id);continue;}for(const z of n.zombies){if(dz.has(z.id))continue;if(dist(b.position,z.position)<=z.radius+4){z.hp-=b.damage;db.add(b.id);break;}}}
 for(const z of n.zombies)if(z.hp<=0){dz.add(z.id);n.score+=z.kind==='brute'?500:z.kind==='heavy'?30:z.kind==='runner'?20:10;n.kills++;if(z.kind==='brute')n.bossDefeated=true;}
 for(const z of n.zombies){if(dz.has(z.id))continue;if(dist(z.position,n.player.position)<=n.player.radius+z.radius&&n.player.invulnerable<=0){dz.add(z.id);n.player.hp-=z.damage;n.player.invulnerable=.35;}}
 for(const p of n.pickups){if(dist(p.position,n.player.position)<30){if(p.kind==='ammo')n.player.ammo+=45;if(p.kind==='health')n.player.hp=Math.min(100,n.player.hp+35);if(p.kind==='grenade')n.player.grenades+=2;if(p.kind==='drone')n.droneCharges++;p.position={x:-999,y:-999};}}
 n.pickups=n.pickups.filter(p=>p.position.x>=0);n.zombies=n.zombies.filter(z=>!dz.has(z.id));n.bullets=n.bullets.filter(b=>!db.has(b.id)&&b.ttl>0);
 if(n.player.hp<=0){n.player.hp=0;n.gameOver=true;}return n;
}
