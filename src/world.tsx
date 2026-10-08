import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { PickupKind } from './game';

type Prop = { x: number; y: number; width?: number; height?: number };
function Positioned({ x, y, width=50, height=50, children }: Prop & {children: React.ReactNode}) {
 return <View pointerEvents="none" style={{position:'absolute',left:x,top:y,width,height}}>{children}</View>;
}
export function WastelandScenery({width,height}:{width:number;height:number}) {
 return <View pointerEvents="none" style={StyleSheet.absoluteFill}>
   <Positioned x={width*.10} y={height*.11} width={64} height={36}>
    <View style={s.carShadow}/><View style={s.carBody}><View style={s.windshield}/><View style={s.rust}/></View>
   </Positioned>
   <Positioned x={width*.73} y={height*.35} width={55} height={78}>
    <View style={[s.carBody,{width:40,height:70,backgroundColor:'#414342'}]}/><View style={[s.windshield,{width:29,top:17,left:5}]}/>
   </Positioned>
   <Positioned x={width*.16} y={height*.56} width={44} height={24}>
    <View style={s.barricade}/><View style={[s.barricadeStripe,{left:9}]}/><View style={[s.barricadeStripe,{left:28}]}/>
   </Positioned>
   <Positioned x={width*.75} y={height*.79} width={44} height={24}>
    <View style={s.barricade}/><View style={[s.barricadeStripe,{left:9}]}/><View style={[s.barricadeStripe,{left:28}]}/>
   </Positioned>
   <Positioned x={width*.19} y={height*.83} width={28} height={28}><View style={s.barrel}><View style={s.barrelTop}/></View></Positioned>
   <Positioned x={width*.72} y={height*.12} width={28} height={28}><View style={s.barrel}><View style={s.barrelTop}/></View></Positioned>
   <Positioned x={width*.43} y={height*.27} width={60} height={25}>
    <View style={s.debris}/><View style={[s.debris,{left:17,top:12,width:15,height:6,transform:[{rotate:'-30deg'}]}]}/>
   </Positioned>
 </View>;
}
export function PickupMarker({kind}:{kind:PickupKind}) {
 const glyph:Record<PickupKind,string>={health:'+',ammo:'▣',grenade:'●',drone:'⌁'};
 const color:Record<PickupKind,string>={health:'#79d9a1',ammo:'#f4bf5b',grenade:'#e86c4c',drone:'#80c7ef'};
 return <View style={[s.pickup,{borderColor:color[kind]}]}><Text style={[s.pickupText,{color:color[kind]}]}>{glyph[kind]}</Text></View>;
}
export function MuzzleFlash({x,y}:{x:number;y:number}) {
 return <View pointerEvents="none" style={[s.muzzle,{left:x-10,top:y-10}]}><View style={s.muzzleCore}/></View>;
}
export function ExplosionRing({x,y,size=80}:{x:number;y:number;size?:number}) {
 return <View pointerEvents="none" style={{position:'absolute',left:x-size/2,top:y-size/2,width:size,height:size,borderRadius:size/2,borderWidth:5,borderColor:'rgba(250,124,46,.75)',backgroundColor:'rgba(235,83,22,.18)'}}/>;
}
const s=StyleSheet.create({
 carShadow:{position:'absolute',left:3,top:7,width:61,height:30,borderRadius:9,backgroundColor:'rgba(0,0,0,.5)'},
 carBody:{position:'absolute',left:0,top:0,width:62,height:31,borderRadius:8,backgroundColor:'#6a4a37',borderWidth:3,borderColor:'#2a2522'},
 windshield:{position:'absolute',left:18,top:3,width:23,height:23,borderRadius:4,backgroundColor:'#242f31',borderWidth:2,borderColor:'#888176'},
 rust:{position:'absolute',left:3,top:23,width:18,height:4,backgroundColor:'#9a492e'},
 barricade:{position:'absolute',width:44,height:22,borderRadius:3,backgroundColor:'#4e4940',borderWidth:3,borderColor:'#242421'},
 barricadeStripe:{position:'absolute',top:4,width:6,height:15,backgroundColor:'#d48d3d',transform:[{rotate:'25deg'}]},
 barrel:{width:25,height:25,borderRadius:12,backgroundColor:'#7e4a31',borderWidth:3,borderColor:'#2c2a28'},
 barrelTop:{position:'absolute',left:4,top:4,width:11,height:11,borderRadius:6,backgroundColor:'#352f2a'},
 debris:{position:'absolute',width:26,height:8,borderRadius:2,backgroundColor:'#51463a',transform:[{rotate:'15deg'}]},
 pickup:{width:27,height:27,borderRadius:7,backgroundColor:'#201e1c',borderWidth:2,alignItems:'center',justifyContent:'center'},
 pickupText:{fontSize:17,fontWeight:'900'},
 muzzle:{position:'absolute',width:20,height:20,borderRadius:10,backgroundColor:'rgba(255,164,50,.22)',borderWidth:3,borderColor:'#ffb84e'},
 muzzleCore:{position:'absolute',left:5,top:5,width:4,height:4,borderRadius:2,backgroundColor:'#fff3b2'},
});
