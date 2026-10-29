<script setup lang="ts">
import { Eye } from 'lucide-vue-next'
import { computed } from 'vue'
import type { StreamInfo } from '@/shared/types'
import { compactNumber } from '../format'
import { t } from '../i18n'
import { thumbnails } from '../thumbnails'
import LiveBadge from './LiveBadge.vue'
import UserAvatar from './UserAvatar.vue'

const props = defineProps<{ stream: StreamInfo; categoryName: string }>()
defineEmits<{ open: [] }>()

const thumbnail = computed(() => thumbnails.get(props.stream.id)?.image)
</script>

<template>
  <button class="stream-card" @click="$emit('open')">
    <span class="stream-card__media" :class="`stream-card__media--${stream.streamer.avatarColor}`">
      <img v-if="thumbnail" :src="thumbnail" alt="" class="stream-card__image" />
      <span v-else class="stream-card__placeholder">
        <UserAvatar :name="stream.streamer.username" :color="stream.streamer.avatarColor" :size="54" />
      </span>
      <span class="stream-card__top">
        <LiveBadge />
      </span>
      <span class="stream-card__viewers">
        <Eye :size="14" :stroke-width="2.4" />
        {{ compactNumber(stream.viewers) }}
      </span>
      <span v-if="stream.paused" class="stream-card__paused">{{ t('watch.paused') }}</span>
    </span>
    <span class="stream-card__meta">
      <UserAvatar :name="stream.streamer.username" :color="stream.streamer.avatarColor" :size="36" live />
      <span class="stream-card__text">
        <span class="stream-card__title">{{ stream.title }}</span>
        <span class="stream-card__sub">@{{ stream.streamer.username }} · {{ categoryName }}</span>
      </span>
    </span>
  </button>
</template>

<style scoped>
.stream-card {
  display: block;
  width: 100%;
  text-align: left;
  border-radius: var(--radius-l);
  transition: transform 140ms var(--ease);
}

.stream-card:active {
  transform: scale(0.985);
}

.stream-card__media {
  position: relative;
  display: block;
  aspect-ratio: 16 / 9;
  border-radius: var(--radius-l);
  overflow: hidden;
  background: var(--surface-2);
}

.stream-card__media--sunset {
  background: radial-gradient(circle at 30% 20%, rgba(255, 154, 61, 0.45), transparent 60%), var(--surface-2);
}

.stream-card__media--ocean {
  background: radial-gradient(circle at 30% 20%, rgba(61, 209, 255, 0.4), transparent 60%), var(--surface-2);
}

.stream-card__media--lime {
  background: radial-gradient(circle at 30% 20%, rgba(196, 242, 61, 0.35), transparent 60%), var(--surface-2);
}

.stream-card__media--grape {
  background: radial-gradient(circle at 30% 20%, rgba(194, 123, 255, 0.4), transparent 60%), var(--surface-2);
}

.stream-card__media--ember {
  background: radial-gradient(circle at 30% 20%, rgba(255, 210, 63, 0.4), transparent 60%), var(--surface-2);
}

.stream-card__media--steel {
  background: radial-gradient(circle at 30% 20%, rgba(163, 173, 194, 0.35), transparent 60%), var(--surface-2);
}

.stream-card__image {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.stream-card__placeholder {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
}

.stream-card__top {
  position: absolute;
  top: 10px;
  left: 10px;
}

.stream-card__viewers {
  position: absolute;
  left: 10px;
  bottom: 10px;
  display: inline-flex;
  align-items: center;
  gap: 5px;
  height: 24px;
  padding: 0 8px;
  border-radius: 6px;
  background: var(--glass);
  backdrop-filter: blur(10px);
  color: #fff;
  font-size: 12px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

.stream-card__paused {
  position: absolute;
  right: 10px;
  bottom: 10px;
  height: 24px;
  padding: 0 8px;
  border-radius: 6px;
  background: var(--glass);
  color: #fff;
  font-size: 12px;
  font-weight: 700;
  line-height: 24px;
}

.stream-card__meta {
  display: flex;
  gap: 10px;
  align-items: center;
  padding: 10px 2px 0;
}

.stream-card__text {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.stream-card__title {
  overflow: hidden;
  font-weight: 700;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.stream-card__sub {
  overflow: hidden;
  color: var(--text-2);
  font-size: 13px;
  white-space: nowrap;
  text-overflow: ellipsis;
}
</style>
