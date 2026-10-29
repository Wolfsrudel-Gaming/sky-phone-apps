<script setup lang="ts">
import { Check, Info, LogOut } from 'lucide-vue-next'
import { computed, ref } from 'vue'
import { rpc } from '@/shared/nui'
import type { Account, AvatarColor } from '@/shared/types'
import UserAvatar from '../components/UserAvatar.vue'
import { longDate } from '../format'
import { errorText, t } from '../i18n'
import { useSnitch } from '../store'

const COLORS: AvatarColor[] = ['sunset', 'ember', 'lime', 'ocean', 'grape', 'steel']

const store = useSnitch()
const account = computed(() => store.account)
const bio = ref(store.account?.bio ?? '')
const saving = ref(false)

async function save(patch: { avatarColor?: AvatarColor; bio?: string }): Promise<void> {
  saving.value = true
  const result = await rpc<{ account: Account }>('profile:update', patch)
  saving.value = false
  if (!result.ok) {
    store.showToast(errorText(result.error), 'error')
    return
  }
  store.account = result.data.account
  store.showToast(t('profile.saved'), 'success')
}
</script>

<template>
  <section class="screen screen--tabs">
    <div v-if="account" class="screen__scroll">
      <header class="page-header">
        <h1 class="page-title">{{ t('profile.title') }}</h1>
      </header>

      <div class="profile__hero">
        <UserAvatar :name="account.username" :color="account.avatarColor" :size="84" />
        <h2 class="profile__name">@{{ account.username }}</h2>
        <p class="muted small">{{ account.email }}</p>
        <p class="muted small">{{ t('profile.memberSince', { date: longDate(account.createdAt) }) }}</p>
      </div>

      <h3 class="section-title">{{ t('profile.color') }}</h3>
      <div class="profile__colors">
        <button
          v-for="color in COLORS"
          :key="color"
          class="profile__color"
          :aria-label="color"
          :aria-pressed="account.avatarColor === color"
          :disabled="saving"
          @click="save({ avatarColor: color })"
        >
          <UserAvatar :name="account.username" :color="color" :size="44" />
          <span v-if="account.avatarColor === color" class="profile__check"><Check :size="14" :stroke-width="3" /></span>
        </button>
      </div>

      <label class="field profile__bio">
        <span class="field__label">{{ t('profile.bio') }}</span>
        <textarea v-model="bio" class="field__input" maxlength="160" :placeholder="t('profile.bioPlaceholder')" />
      </label>
      <button
        class="btn btn--ghost btn--block"
        :disabled="saving || bio.trim() === account.bio"
        @click="save({ bio: bio.trim() })"
      >
        {{ t('common.save') }}
      </button>

      <p class="notice profile__payout">
        <Info :size="16" />
        {{ account.isPayoutOwner ? t('profile.payoutOwner') : t('profile.payoutOther') }}
      </p>

      <div class="profile__logout">
        <button class="btn btn--ghost btn--block" @click="store.logout(false)">
          <LogOut :size="18" /> {{ t('profile.logout') }}
        </button>
        <button class="btn btn--danger-text btn--block" @click="store.logout(true)">
          {{ t('profile.logoutAll') }}
        </button>
      </div>
    </div>
  </section>
</template>

<style scoped>
.profile__hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin: 8px 0 8px;
  text-align: center;
}

.profile__hero p {
  margin: 2px 0 0;
}

.profile__name {
  margin: 12px 0 2px;
  font-size: 22px;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.profile__colors {
  display: flex;
  justify-content: space-between;
  margin-bottom: 18px;
}

.profile__color {
  position: relative;
  border-radius: 50%;
  transition: transform 120ms var(--ease);
}

.profile__color:active {
  transform: scale(0.92);
}

.profile__check {
  position: absolute;
  right: -2px;
  bottom: -2px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: var(--text);
  color: var(--bg);
  border: 2px solid var(--bg);
}

.profile__payout {
  margin: 18px 0;
}

.profile__logout {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
</style>
