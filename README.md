# sky-phone-apps

Eigene Apps für [Sky Phone](https://github.com/sky-systems/sky_phone). Jede App ist
eine eigene FiveM-Resource. Man kopiert sie in `resources/` und startet sie nach
`sky_phone`. Die Konfiguration von Sky Phone bleibt dabei unverändert.

| App                | Beschreibung                                              | Status                |
| ------------------ | --------------------------------------------------------- | --------------------- |
| [Snitch](snitch/)  | Livestreaming mit Chat, Spenden, Steuern und Einnahmen     | Phase 1, ungetestet in FiveM |

## Aufbau

```
snitch/            fertige Resource (inkl. gebauter Oberfläche in snitch/web)
src/snitch/        Quellcode der Oberfläche (Vue 3, Vite, TypeScript)
tests/             Tests für die Server-Logik (Lua 5.4)
```

Die gebaute Oberfläche (`snitch/web`) liegt mit im Repository. Server-Betreiber
brauchen dadurch kein Node.js, sie kopieren einfach den Ordner `snitch`.

## Entwicklung

```bash
cd src/snitch
pnpm install
pnpm dev
```

Danach `http://localhost:5180/app.html` öffnen. Im Browser läuft die App mit
Testdaten und einem simulierten Stream. Folgende URL-Optionen gibt es:

| Option        | Wirkung                       |
| ------------- | ----------------------------- |
| `?mock=guest` | ausgeloggt starten            |
| `?scheme=light` | heller Modus                |
| `?lang=en`    | englische Texte               |
| `?empty=1`    | keine laufenden Streams       |

Vor einem Commit:

```bash
cd src/snitch
pnpm test
pnpm build
```

`pnpm build` prüft die Typen und schreibt die fertige Oberfläche nach `snitch/web`.

Die Server-Logik wird ohne FiveM getestet:

```bash
lua5.4 tests/split_test.lua
lua5.4 tests/server_flow_test.lua
```

## Regeln für neue Apps

- Jede App registriert sich selbst über `exports.sky_phone:AddCustomApp(...)` und
  registriert sich erneut bei `sky_phone:client:apiReady`.
- Hilfscode wird in jede App kopiert und **nicht** als gemeinsame Resource
  geteilt. Sky Phone ordnet eine App der Resource zu, die den Export aufruft.
- App-IDs dürfen keine eingebauten Sky-Phone-Apps überschreiben. Eigene IDs sollten
  eindeutig sein.
- Geld, Rechte und Identität prüft immer der Server.
