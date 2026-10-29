<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { createGameView, type GameView } from '@/shared/gameView'

// The streamer's own camera picture inside the phone. If FiveM does not hand the
// game picture to this frame, the component stays invisible and costs nothing.

const props = withDefaults(defineProps<{ fps?: number; active?: boolean }>(), { fps: 24, active: true })

const canvas = ref<HTMLCanvasElement | null>(null)
const available = ref(false)
let view: GameView | null = null
let animation = 0

function resize(): void {
  if (!view || !canvas.value) return
  const rect = canvas.value.getBoundingClientRect()
  const scale = Math.min(window.devicePixelRatio || 1, 2)
  view.resize(rect.width * scale, rect.height * scale)
}

onMounted(() => {
  if (!canvas.value) return
  try {
    view = createGameView(canvas.value)
  } catch {
    return
  }
  resize()

  // Reading pixels stalls the GPU, so only every sixth frame is checked, for about 1.5 s.
  let frames = 0
  let previous = 0
  const frame = (now: number) => {
    animation = requestAnimationFrame(frame)
    if (!view) return
    if (!available.value) {
      frames += 1
      if (frames % 6 !== 0) return
      if (view.isLive()) {
        available.value = true
      } else if (frames >= 90) {
        cancelAnimationFrame(animation)
        view.dispose()
        view = null
      }
      return
    }
    if (!props.active || now - previous < 1000 / props.fps) return
    previous = now
    view.render()
  }
  animation = requestAnimationFrame(frame)
  window.addEventListener('resize', resize)
})

onBeforeUnmount(() => {
  cancelAnimationFrame(animation)
  window.removeEventListener('resize', resize)
  view?.dispose()
  view = null
})
</script>

<template>
  <canvas ref="canvas" class="game-preview" :class="{ 'game-preview--on': available }" aria-hidden="true" />
</template>

<style scoped>
.game-preview {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  transition: opacity 300ms var(--ease);
}

.game-preview--on {
  opacity: 1;
}
</style>
