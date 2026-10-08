import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  PanResponder,
  Pressable,
  SafeAreaView,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';
import { createGame, GameState, updateGame, Vec } from './src/game';

const HUD_HEIGHT = 86;

export default function App() {
  const window = useWindowDimensions();
  const arenaWidth = Math.max(280, window.width);
  const arenaHeight = Math.max(420, window.height - HUD_HEIGHT);
  const [game, setGame] = useState<GameState>(() => createGame(arenaWidth, arenaHeight));
  const moveRef = useRef<Vec>({ x: 0, y: 0 });
  const stickOrigin = useRef<Vec | null>(null);

  useEffect(() => {
    setGame(createGame(arenaWidth, arenaHeight));
  }, [arenaWidth, arenaHeight]);

  useEffect(() => {
    let previous = Date.now();
    const timer = setInterval(() => {
      const now = Date.now();
      const dt = Math.min(0.05, (now - previous) / 1000);
      previous = now;
      setGame((current) => updateGame(current, { move: moveRef.current }, dt));
    }, 33);
    return () => clearInterval(timer);
  }, []);

  const panResponder = useMemo(
    () =>
      PanResponder.create({
        onStartShouldSetPanResponder: () => true,
        onMoveShouldSetPanResponder: () => true,
        onPanResponderGrant: (event) => {
          stickOrigin.current = {
            x: event.nativeEvent.pageX,
            y: event.nativeEvent.pageY,
          };
        },
        onPanResponderMove: (event) => {
          const origin = stickOrigin.current;
          if (!origin) return;
          moveRef.current = {
            x: event.nativeEvent.pageX - origin.x,
            y: event.nativeEvent.pageY - origin.y,
          };
        },
        onPanResponderRelease: () => {
          moveRef.current = { x: 0, y: 0 };
          stickOrigin.current = null;
        },
        onPanResponderTerminate: () => {
          moveRef.current = { x: 0, y: 0 };
          stickOrigin.current = null;
        },
      }),
    [],
  );

  const reset = () => {
    moveRef.current = { x: 0, y: 0 };
    setGame(createGame(arenaWidth, arenaHeight));
  };

  return (
    <SafeAreaView style={styles.root}>
      <View style={styles.hud}>
        <Text style={styles.title}>DEADSHIFT</Text>
        <Text style={styles.hudText}>Wave {game.wave}</Text>
        <Text style={styles.hudText}>HP {game.player.hp}</Text>
        <Text style={styles.hudText}>Score {game.score}</Text>
      </View>

      <View style={[styles.arena, { width: arenaWidth, height: arenaHeight }]} {...panResponder.panHandlers}>
        {game.zombies.map((zombie) => (
          <View
            key={zombie.id}
            style={[
              styles.zombie,
              {
                left: zombie.position.x - 14,
                top: zombie.position.y - 14,
              },
            ]}
          />
        ))}

        {game.bullets.map((bullet) => (
          <View
            key={bullet.id}
            style={[
              styles.bullet,
              {
                left: bullet.position.x - 3,
                top: bullet.position.y - 3,
              },
            ]}
          />
        ))}

        <View
          style={[
            styles.player,
            {
              left: game.player.position.x - game.player.radius,
              top: game.player.position.y - game.player.radius,
            },
          ]}
        />

        <View style={styles.instructions}>
          <Text style={styles.instructionsText}>Drag anywhere to move · auto-fire enabled</Text>
        </View>

        {game.gameOver && (
          <View style={styles.overlay}>
            <Text style={styles.gameOver}>SHIFT OVER</Text>
            <Text style={styles.finalScore}>Score {game.score} · Wave {game.wave}</Text>
            <Pressable onPress={reset} style={styles.button}>
              <Text style={styles.buttonText}>RUN IT BACK</Text>
            </Pressable>
          </View>
        )}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#080a0d',
  },
  hud: {
    height: HUD_HEIGHT,
    paddingHorizontal: 16,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    borderBottomWidth: 1,
    borderBottomColor: '#242a30',
  },
  title: {
    color: '#f2f4f5',
    fontWeight: '900',
    fontSize: 18,
    letterSpacing: 1.5,
    marginRight: 'auto',
  },
  hudText: {
    color: '#b9c0c7',
    fontWeight: '700',
    fontSize: 13,
  },
  arena: {
    position: 'relative',
    overflow: 'hidden',
    backgroundColor: '#0d1116',
  },
  player: {
    position: 'absolute',
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#e9edf0',
    borderWidth: 4,
    borderColor: '#7bff96',
  },
  zombie: {
    position: 'absolute',
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: '#5c7f54',
    borderWidth: 2,
    borderColor: '#a3c88d',
  },
  bullet: {
    position: 'absolute',
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: '#ffd166',
  },
  instructions: {
    position: 'absolute',
    bottom: 22,
    alignSelf: 'center',
    backgroundColor: 'rgba(0,0,0,0.46)',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 12,
  },
  instructionsText: {
    color: '#d5d9dd',
    fontSize: 12,
  },
  overlay: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(4,5,7,0.84)',
  },
  gameOver: {
    color: '#f2f4f5',
    fontSize: 34,
    fontWeight: '900',
    letterSpacing: 2,
  },
  finalScore: {
    color: '#b9c0c7',
    marginTop: 10,
    marginBottom: 24,
  },
  button: {
    paddingHorizontal: 22,
    paddingVertical: 14,
    borderRadius: 12,
    backgroundColor: '#7bff96',
  },
  buttonText: {
    color: '#09100b',
    fontWeight: '900',
  },
});
