import { computed } from 'vue'
import { phoneContext } from './bridge'

const de = {
  'lock.title': 'Gesperrt',
  'lock.enterPin': 'PIN eingeben',
  'lock.wrong': 'Falsch. Noch {count} Versuche.',
  'lock.locked': 'Zu viele Fehlversuche. Gesperrt bis {time}.',
  'lock.wiped': 'Die App hat sich selbst gelöscht.',
  'lock.extract': 'Gerät auswerten',
  'lock.extracting': 'Auswertung läuft … {seconds} s',
  'lock.extractHint': 'Polizei: Daten dieses Handys ohne PIN auslesen (nur lesen).',
  'readonly': 'Polizeiliche Auswertung – nur lesen',
  'tabs.channels': 'Kanäle',
  'tabs.messages': 'Privat',
  'tabs.settings': 'Ich',
  'channels.title': 'Kanäle',
  'channels.today': '{count} heute',
  'channels.quiet': 'still',
  'channels.noPin': 'Kein PIN gesetzt. Jeder mit deinem Handy liest mit.',
  'channels.setPin': 'PIN setzen',
  'feed.empty': 'Noch nichts hier. Fang an.',
  'feed.placeholder': 'Anonym schreiben …',
  'feed.ad': 'Anzeige',
  'feed.reply': 'Privat antworten',
  'feed.you': 'du',
  'feed.expire': 'Nachrichten verschwinden nach {hours} h.',
  'threads.title': 'Privat',
  'threads.empty': 'Keine privaten Gespräche. Antworte auf eine Anzeige, um eins zu starten.',
  'thread.placeholder': 'Nachricht …',
  'settings.title': 'Ich',
  'settings.alias': 'Deckname',
  'settings.aliasHint': 'Ändern alle 24 h möglich.',
  'settings.aliasRandom': 'Neuen Decknamen würfeln',
  'settings.aliasNext': 'Nächste Änderung: {time}',
  'settings.pin': 'PIN-Sperre',
  'settings.pinOn': 'Aktiv – beim Öffnen wird der PIN abgefragt.',
  'settings.pinOff': 'Aus – jeder mit deinem Handy kommt rein.',
  'settings.pinNew': 'Neuer PIN ({length} Ziffern)',
  'settings.pinRemove': 'PIN entfernen',
  'settings.wipeNote': 'Mehrfach falscher PIN sperrt die App, irgendwann löscht sie sich selbst.',
  'common.save': 'Speichern',
  'common.back': 'Zurück',
  'common.saved': 'Gespeichert',
  'error.generic': 'Fehlgeschlagen.',
  'error.invalid_alias': 'Ungültiger Deckname.',
  'error.alias_taken': 'Deckname vergeben.',
  'error.alias_cooldown': 'Noch nicht wieder änderbar.',
  'error.invalid_pin': 'Ungültiger PIN.',
  'error.own_message': 'Das ist deine eigene Nachricht.',
  'error.message_gone': 'Die Nachricht gibt es nicht mehr.',
  'error.rate_limited': 'Langsam.',
  'error.text_too_long': 'Zu lang.',
  'error.empty_text': 'Leer.',
  'error.not_ready': 'Auswertung noch nicht fertig.',
  'error.own_phone': 'Das ist dein eigenes Handy.',
  'error.locked': 'Gesperrt.',
  'error.no_phone': 'Kein Handy.',
  'error.not_installed': 'Nicht verfügbar.',
}

type Key = keyof typeof de

const en: Record<Key, string> = {
  'lock.title': 'Locked',
  'lock.enterPin': 'Enter PIN',
  'lock.wrong': 'Wrong. {count} attempts left.',
  'lock.locked': 'Too many wrong attempts. Locked until {time}.',
  'lock.wiped': 'The app deleted itself.',
  'lock.extract': 'Extract device',
  'lock.extracting': 'Extracting … {seconds} s',
  'lock.extractHint': 'Police: read this phone without the PIN (read only).',
  'readonly': 'Police extraction – read only',
  'tabs.channels': 'Channels',
  'tabs.messages': 'Private',
  'tabs.settings': 'Me',
  'channels.title': 'Channels',
  'channels.today': '{count} today',
  'channels.quiet': 'quiet',
  'channels.noPin': 'No PIN set. Anyone with your phone can read along.',
  'channels.setPin': 'Set PIN',
  'feed.empty': 'Nothing here yet. Start it.',
  'feed.placeholder': 'Write anonymously …',
  'feed.ad': 'Offer',
  'feed.reply': 'Reply privately',
  'feed.you': 'you',
  'feed.expire': 'Messages disappear after {hours} h.',
  'threads.title': 'Private',
  'threads.empty': 'No private conversations. Reply to an offer to start one.',
  'thread.placeholder': 'Message …',
  'settings.title': 'Me',
  'settings.alias': 'Alias',
  'settings.aliasHint': 'Can be changed every 24 h.',
  'settings.aliasRandom': 'Roll a new alias',
  'settings.aliasNext': 'Next change: {time}',
  'settings.pin': 'PIN lock',
  'settings.pinOn': 'On – the PIN is asked every time the app opens.',
  'settings.pinOff': 'Off – anyone with your phone gets in.',
  'settings.pinNew': 'New PIN ({length} digits)',
  'settings.pinRemove': 'Remove PIN',
  'settings.wipeNote': 'Repeated wrong PINs lock the app; eventually it deletes itself.',
  'common.save': 'Save',
  'common.back': 'Back',
  'common.saved': 'Saved',
  'error.generic': 'Failed.',
  'error.invalid_alias': 'Invalid alias.',
  'error.alias_taken': 'Alias taken.',
  'error.alias_cooldown': 'Cannot change it yet.',
  'error.invalid_pin': 'Invalid PIN.',
  'error.own_message': 'That is your own message.',
  'error.message_gone': 'That message is gone.',
  'error.rate_limited': 'Slow down.',
  'error.text_too_long': 'Too long.',
  'error.empty_text': 'Empty.',
  'error.not_ready': 'Extraction not finished yet.',
  'error.own_phone': 'This is your own phone.',
  'error.locked': 'Locked.',
  'error.no_phone': 'No phone.',
  'error.not_installed': 'Not available.',
}

export const language = computed<'de' | 'en'>(() =>
  phoneContext.language.toLowerCase().startsWith('de') ? 'de' : 'en',
)

export function t(key: Key, params: Record<string, string | number> = {}): string {
  const table = language.value === 'de' ? de : en
  return table[key].replace(/\{(\w+)\}/g, (_, name: string) => String(params[name] ?? ''))
}

export function errorText(code: string | undefined): string {
  const key = `error.${code}` as Key
  return key in de ? t(key) : t('error.generic')
}

export function label(labels: Record<string, string>, fallback: string): string {
  return labels[language.value] ?? labels.en ?? fallback
}

export function clockTime(unixSeconds: number): string {
  return new Intl.DateTimeFormat(language.value === 'de' ? 'de-DE' : 'en-US', {
    hour: '2-digit',
    minute: '2-digit',
  }).format(unixSeconds * 1000)
}

export function relative(unixSeconds: number): string {
  const seconds = Math.max(0, Date.now() / 1000 - unixSeconds)
  if (seconds < 60) return language.value === 'de' ? 'jetzt' : 'now'
  if (seconds < 3600) return `${Math.floor(seconds / 60)} min`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)} h`
  return `${Math.floor(seconds / 86400)} d`
}
