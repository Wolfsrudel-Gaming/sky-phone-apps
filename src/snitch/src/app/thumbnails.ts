import { reactive } from 'vue'
import { rpc } from '@/shared/nui'
import type { StreamInfo } from '@/shared/types'

interface Thumbnail {
  version: number
  image: string
}

/** Preview images by stream id. Only fetched when the stream reports a newer version. */
export const thumbnails = reactive(new Map<number, Thumbnail>())
const loading = new Set<number>()

export async function refreshThumbnails(streams: StreamInfo[]): Promise<void> {
  const live = new Set(streams.map((stream) => stream.id))
  for (const id of [...thumbnails.keys()]) {
    if (!live.has(id)) thumbnails.delete(id)
  }

  await Promise.all(
    streams.map(async (stream) => {
      const cached = thumbnails.get(stream.id)
      if (stream.thumbnailVersion === 0 || (cached && cached.version >= stream.thumbnailVersion)) return
      if (loading.has(stream.id)) return
      loading.add(stream.id)
      const result = await rpc<{ id: number; version: number; image: string }>('streams:thumbnail', {
        id: stream.id,
      })
      loading.delete(stream.id)
      if (result.ok) thumbnails.set(stream.id, { version: result.data.version, image: result.data.image })
    }),
  )
}
