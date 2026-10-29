<script setup lang="ts">
import { computed } from 'vue'
import type { AvatarColor } from '@/shared/types'

const props = withDefaults(
  defineProps<{
    name: string
    color?: AvatarColor
    size?: number
    live?: boolean
  }>(),
  { color: 'sunset', size: 40, live: false },
)

const initial = computed(() => props.name.slice(0, 1).toUpperCase())
</script>

<template>
  <span
    class="avatar"
    :class="[`avatar--${color}`, { 'avatar--live': live }]"
    :style="{ width: `${size}px`, height: `${size}px`, fontSize: `${Math.round(size * 0.42)}px` }"
    aria-hidden="true"
  >
    {{ initial }}
  </span>
</template>

<style scoped>
.avatar {
  position: relative;
  display: inline-flex;
  flex: none;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  color: #fff;
  font-weight: 800;
  letter-spacing: -0.02em;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.25);
}

.avatar--live::after {
  content: '';
  position: absolute;
  inset: -3px;
  border-radius: 50%;
  border: 2px solid var(--live);
}

.avatar--sunset {
  background: linear-gradient(135deg, #ff9a3d, #ff3d77);
}

.avatar--ocean {
  background: linear-gradient(135deg, #3dd1ff, #3d5cff);
}

.avatar--lime {
  background: linear-gradient(135deg, #c4f23d, #22b67a);
}

.avatar--grape {
  background: linear-gradient(135deg, #c27bff, #6a3dff);
}

.avatar--ember {
  background: linear-gradient(135deg, #ffd23f, #ff6a2b);
  color: #2a1605;
  text-shadow: none;
}

.avatar--steel {
  background: linear-gradient(135deg, #a3adc2, #535c70);
}
</style>
