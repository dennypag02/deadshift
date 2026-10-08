import React from 'react';
import { StyleSheet, View } from 'react-native';
import type { ZombieKind } from './game';

type SurvivorProps = {
  size?: number;
};

export function SurvivorSprite({ size = 46 }: SurvivorProps) {
  const scale = size / 46;
  return (
    <View style={[styles.spriteRoot, { width: size, height: size }]}>
      <View style={[styles.shadow, { transform: [{ scale }] }]} />
      <View style={[styles.survivorBody, { transform: [{ scale }] }]}>
        <View style={styles.survivorLegLeft} />
        <View style={styles.survivorLegRight} />
        <View style={styles.survivorTorso} />
        <View style={styles.shoulderLeft} />
        <View style={styles.shoulderRight} />
        <View style={styles.armLeft} />
        <View style={styles.armRight} />
        <View style={styles.head} />
        <View style={styles.mohawk} />
        <View style={styles.scarfKnot} />
        <View style={styles.scarfTail} />
        <View style={styles.rifleStock} />
        <View style={styles.rifleBody} />
        <View style={styles.rifleBarrel} />
      </View>
    </View>
  );
}

type ZombieProps = {
  kind: ZombieKind;
  size: number;
};

export function ZombieSprite({ kind, size }: ZombieProps) {
  const scale = size / 42;
  return (
    <View style={[styles.spriteRoot, { width: size, height: size }]}>
      <View style={[styles.zombieShadow, { transform: [{ scale }] }]} />
      <View style={[styles.zombieBody, { transform: [{ scale }] }]}>
        <View style={[styles.zombieLegLeft, kind === 'runner' && styles.runnerLimb]} />
        <View style={[styles.zombieLegRight, kind === 'runner' && styles.runnerLimb]} />
        <View
          style={[
            styles.zombieTorso,
            kind === 'runner' && styles.runnerTorso,
            kind === 'heavy' && styles.heavyTorso,
            kind === 'brute' && styles.bruteTorso,
          ]}
        />
        <View style={[styles.zombieArmLeft, kind === 'brute' && styles.bruteArm]} />
        <View style={[styles.zombieArmRight, kind === 'brute' && styles.bruteArm]} />
        <View
          style={[
            styles.zombieHead,
            kind === 'runner' && styles.runnerHead,
            kind === 'heavy' && styles.heavyHead,
            kind === 'brute' && styles.bruteHead,
          ]}
        />
        {kind === 'heavy' && <View style={styles.heavyPlate} />}
        {kind === 'brute' && (
          <>
            <View style={styles.bruteShoulderLeft} />
            <View style={styles.bruteShoulderRight} />
          </>
        )}
      </View>
    </View>
  );
}

export function AsphaltBackdrop() {
  return (
    <View pointerEvents="none" style={StyleSheet.absoluteFill}>
      <View style={styles.roadBandLeft} />
      <View style={styles.roadBandRight} />
      <View style={[styles.roadStripe, { top: '12%' }]} />
      <View style={[styles.roadStripe, { top: '39%' }]} />
      <View style={[styles.roadStripe, { top: '66%' }]} />
      <View style={[styles.roadStripe, { top: '88%' }]} />
      <View style={[styles.crack, { left: '16%', top: '22%', transform: [{ rotate: '17deg' }] }]} />
      <View style={[styles.crack, { left: '58%', top: '52%', transform: [{ rotate: '-24deg' }] }]} />
      <View style={[styles.crackSmall, { left: '33%', top: '73%', transform: [{ rotate: '42deg' }] }]} />
      <View style={[styles.bloodSmear, { left: '72%', top: '30%' }]} />
      <View style={[styles.bloodSmearSmall, { left: '21%', top: '60%' }]} />
    </View>
  );
}

const styles = StyleSheet.create({
  spriteRoot: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  shadow: {
    position: 'absolute',
    width: 33,
    height: 15,
    borderRadius: 16,
    backgroundColor: 'rgba(0,0,0,0.55)',
    bottom: 1,
  },
  survivorBody: {
    position: 'relative',
    width: 46,
    height: 46,
  },
  survivorTorso: {
    position: 'absolute',
    left: 14,
    top: 14,
    width: 18,
    height: 20,
    borderRadius: 6,
    backgroundColor: '#3a332e',
    borderWidth: 2,
    borderColor: '#8a8178',
  },
  survivorLegLeft: {
    position: 'absolute',
    left: 14,
    top: 30,
    width: 7,
    height: 13,
    borderRadius: 3,
    backgroundColor: '#252525',
    transform: [{ rotate: '9deg' }],
  },
  survivorLegRight: {
    position: 'absolute',
    right: 14,
    top: 30,
    width: 7,
    height: 13,
    borderRadius: 3,
    backgroundColor: '#252525',
    transform: [{ rotate: '-9deg' }],
  },
  shoulderLeft: {
    position: 'absolute',
    left: 9,
    top: 15,
    width: 10,
    height: 9,
    borderRadius: 5,
    backgroundColor: '#6f6962',
    borderWidth: 2,
    borderColor: '#252321',
  },
  shoulderRight: {
    position: 'absolute',
    right: 9,
    top: 15,
    width: 10,
    height: 9,
    borderRadius: 5,
    backgroundColor: '#6f6962',
    borderWidth: 2,
    borderColor: '#252321',
  },
  armLeft: {
    position: 'absolute',
    left: 7,
    top: 21,
    width: 7,
    height: 15,
    borderRadius: 4,
    backgroundColor: '#b88865',
    transform: [{ rotate: '18deg' }],
  },
  armRight: {
    position: 'absolute',
    right: 7,
    top: 21,
    width: 7,
    height: 15,
    borderRadius: 4,
    backgroundColor: '#b88865',
    transform: [{ rotate: '-18deg' }],
  },
  head: {
    position: 'absolute',
    left: 17,
    top: 6,
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#b88865',
    borderWidth: 1,
    borderColor: '#5f4133',
  },
  mohawk: {
    position: 'absolute',
    left: 21,
    top: 1,
    width: 5,
    height: 11,
    borderRadius: 2,
    backgroundColor: '#161616',
  },
  scarfKnot: {
    position: 'absolute',
    left: 13,
    top: 14,
    width: 18,
    height: 5,
    borderRadius: 2,
    backgroundColor: '#a52118',
  },
  scarfTail: {
    position: 'absolute',
    right: 5,
    top: 17,
    width: 14,
    height: 5,
    borderRadius: 2,
    backgroundColor: '#8f1c15',
    transform: [{ rotate: '22deg' }],
  },
  rifleStock: {
    position: 'absolute',
    left: 12,
    top: 23,
    width: 10,
    height: 5,
    borderRadius: 2,
    backgroundColor: '#6d4a2f',
    transform: [{ rotate: '-20deg' }],
  },
  rifleBody: {
    position: 'absolute',
    left: 19,
    top: 20,
    width: 21,
    height: 5,
    borderRadius: 2,
    backgroundColor: '#242526',
    borderWidth: 1,
    borderColor: '#77716a',
    transform: [{ rotate: '-20deg' }],
  },
  rifleBarrel: {
    position: 'absolute',
    right: 1,
    top: 16,
    width: 12,
    height: 3,
    backgroundColor: '#202122',
    transform: [{ rotate: '-20deg' }],
  },
  zombieShadow: {
    position: 'absolute',
    width: 31,
    height: 13,
    borderRadius: 15,
    backgroundColor: 'rgba(0,0,0,0.45)',
    bottom: 0,
  },
  zombieBody: {
    position: 'relative',
    width: 42,
    height: 42,
  },
  zombieTorso: {
    position: 'absolute',
    left: 13,
    top: 13,
    width: 16,
    height: 20,
    borderRadius: 6,
    backgroundColor: '#59624b',
    borderWidth: 2,
    borderColor: '#2e3429',
  },
  zombieHead: {
    position: 'absolute',
    left: 16,
    top: 4,
    width: 11,
    height: 11,
    borderRadius: 5,
    backgroundColor: '#7f8b68',
    borderWidth: 1,
    borderColor: '#343b2f',
  },
  zombieArmLeft: {
    position: 'absolute',
    left: 7,
    top: 18,
    width: 6,
    height: 16,
    borderRadius: 3,
    backgroundColor: '#778267',
    transform: [{ rotate: '23deg' }],
  },
  zombieArmRight: {
    position: 'absolute',
    right: 7,
    top: 18,
    width: 6,
    height: 16,
    borderRadius: 3,
    backgroundColor: '#778267',
    transform: [{ rotate: '-23deg' }],
  },
  zombieLegLeft: {
    position: 'absolute',
    left: 13,
    top: 30,
    width: 6,
    height: 10,
    borderRadius: 3,
    backgroundColor: '#373a32',
  },
  zombieLegRight: {
    position: 'absolute',
    right: 13,
    top: 30,
    width: 6,
    height: 10,
    borderRadius: 3,
    backgroundColor: '#373a32',
  },
  runnerTorso: {
    backgroundColor: '#685149',
    borderColor: '#3c2d29',
    transform: [{ rotate: '8deg' }],
  },
  runnerHead: {
    backgroundColor: '#94705e',
  },
  runnerLimb: {
    backgroundColor: '#73594f',
  },
  heavyTorso: {
    width: 21,
    left: 10.5,
    backgroundColor: '#485142',
    borderWidth: 3,
    borderColor: '#242b23',
  },
  heavyHead: {
    width: 13,
    height: 13,
    left: 14.5,
    backgroundColor: '#69735f',
  },
  heavyPlate: {
    position: 'absolute',
    left: 12,
    top: 17,
    width: 18,
    height: 8,
    borderRadius: 2,
    backgroundColor: '#666760',
    borderWidth: 1,
    borderColor: '#262626',
  },
  bruteTorso: {
    left: 6,
    top: 11,
    width: 30,
    height: 25,
    borderRadius: 9,
    backgroundColor: '#64372f',
    borderWidth: 3,
    borderColor: '#2e1513',
  },
  bruteHead: {
    left: 14,
    top: 1,
    width: 15,
    height: 15,
    borderRadius: 6,
    backgroundColor: '#8b5546',
    borderWidth: 2,
    borderColor: '#3b201b',
  },
  bruteArm: {
    width: 9,
    height: 20,
    backgroundColor: '#704137',
  },
  bruteShoulderLeft: {
    position: 'absolute',
    left: 2,
    top: 12,
    width: 12,
    height: 10,
    borderRadius: 5,
    backgroundColor: '#453934',
    borderWidth: 2,
    borderColor: '#1f1917',
  },
  bruteShoulderRight: {
    position: 'absolute',
    right: 2,
    top: 12,
    width: 12,
    height: 10,
    borderRadius: 5,
    backgroundColor: '#453934',
    borderWidth: 2,
    borderColor: '#1f1917',
  },
  roadBandLeft: {
    position: 'absolute',
    left: '2%',
    top: 0,
    bottom: 0,
    width: '9%',
    backgroundColor: '#211d19',
    borderRightWidth: 1,
    borderRightColor: '#3a342f',
  },
  roadBandRight: {
    position: 'absolute',
    right: '2%',
    top: 0,
    bottom: 0,
    width: '9%',
    backgroundColor: '#211d19',
    borderLeftWidth: 1,
    borderLeftColor: '#3a342f',
  },
  roadStripe: {
    position: 'absolute',
    left: '47%',
    width: '6%',
    height: 24,
    borderRadius: 2,
    backgroundColor: 'rgba(176,146,76,0.22)',
  },
  crack: {
    position: 'absolute',
    width: 70,
    height: 2,
    backgroundColor: '#2a2420',
  },
  crackSmall: {
    position: 'absolute',
    width: 38,
    height: 2,
    backgroundColor: '#2a2420',
  },
  bloodSmear: {
    position: 'absolute',
    width: 44,
    height: 18,
    borderRadius: 18,
    backgroundColor: 'rgba(95,18,13,0.32)',
    transform: [{ rotate: '-16deg' }],
  },
  bloodSmearSmall: {
    position: 'absolute',
    width: 28,
    height: 11,
    borderRadius: 12,
    backgroundColor: 'rgba(95,18,13,0.28)',
    transform: [{ rotate: '31deg' }],
  },
});
