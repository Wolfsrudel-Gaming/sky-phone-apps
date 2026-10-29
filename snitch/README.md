# Snitch – Livestreaming für Sky Phone

Snitch ist eine Livestreaming-App für [Sky Phone](https://github.com/sky-systems/sky_phone).
Spieler streamen das Bild ihrer Handykamera, andere schauen zu, chatten mit und
unterstützen Streamer mit Spenden.

Snitch ist eine eigenständige Resource. Die Konfiguration von Sky Phone muss dafür
nicht angepasst werden.

## Funktionen

- **Konto:** Benutzername, E-Mail und Passwort. Die Anmeldung gilt für das Handy,
  auf dem sie gemacht wurde. Mit E-Mail und Passwort meldet man sich auf jedem
  Handy an. „Auf allen Handys abmelden“ beendet alle Anmeldungen.
- **Entdecken:** Alle laufenden Streams mit Vorschaubild, Zuschauerzahl, Laufzeit
  und Kategorie-Filter.
- **Zuschauen:** Video mit Ton, Livechat, Spenden-Einblendungen und eine Anzeige,
  wenn der Streamer gerade pausiert.
- **Live gehen:**
  - Gestreamt wird das Bild der Sky-Phone-Kamera (Rück- oder Selfie-Kamera), in
    Ego-Perspektive und ohne HUD.
  - Der Streamer sieht live, wie viele zuschauen und wie viel der Stream eingebracht
    hat. Er kann das Mikro stummschalten und die Kamera wechseln.
- **Spenden:** Werden sofort vom Bankkonto des Zuschauers abgebucht.
  - Die Plattform behält 50 %, von der verbleibenden Hälfte gehen 15 % Steuern an
    das Staatskonto in okokBanking.
  - Den Rest bekommt der Charakter, der das Konto erstellt hat.
  - Ist dieser Charakter gerade nicht in der Stadt, wird beim nächsten Einloggen
    ausgezahlt.
- **Einnahmen:** Gesamtsumme, Aufteilung in Gebühr und Steuern, die letzten 14 Tage,
  Top-Unterstützer und die letzten Streams.

Beispiel für eine Spende über 1.000 $:

| Posten                         | Betrag  |
| ------------------------------ | ------- |
| Spende (vom Zuschauer)         | 1.000 $ |
| Plattformgebühr 50 %           | −500 $  |
| Steuern 15 % auf den Rest      | −75 $   |
| **Auszahlung an den Streamer** | 425 $   |

Mit `TaxBase = 'gross'` werden die 15 % stattdessen auf die volle Spende berechnet.
Der Streamer bekommt dann 350 $.

## Voraussetzungen

- [Sky Phone](https://github.com/sky-systems/sky_phone) 1.3 oder neuer, mit
  aktivierten Custom Apps. Das ist die Standardeinstellung (`Config.CustomApps`).
- ESX Legacy
- oxmysql
- okokBanking für das Staatskonto und den Transaktionsverlauf. Ohne okokBanking
  funktionieren Spenden trotzdem, nur die Steuern werden nicht gebucht.
- Ein Voice-Script auf Basis von Mumble (pma-voice) für `Voice.Mode = 'talking'`.

## Installation

1. Den Ordner `snitch` nach `resources/` kopieren.
2. In der `server.cfg` **nach** Sky Phone starten:

   ```cfg
   ensure oxmysql
   ensure es_extended
   ensure okokBanking
   ensure sky_phone
   ensure snitch
   ```

3. Server starten. Die Datenbanktabellen (`snitch_*`) werden automatisch angelegt.
4. Spieler installieren Snitch über den App Store im Handy. Mit
   `Config.App.DefaultInstalled = true` ist die App sofort auf jedem Handy.

## Konfiguration (`config.lua`)

| Einstellung                         | Standard       | Bedeutung                                                                       |
| ----------------------------------- | -------------- | ------------------------------------------------------------------------------- |
| `Donations.PlatformFeePercent`      | `50`           | Anteil, den die Plattform behält                                                |
| `Donations.TaxPercent`              | `15`           | Steuersatz                                                                      |
| `Donations.TaxBase`                 | `'afterFee'`   | `'afterFee'`: Steuer auf den Anteil des Streamers, `'gross'`: auf die ganze Spende |
| `Donations.StateAccount`            | `'government'` | okokBanking-Konto für die Steuern                                               |
| `Donations.PlatformAccount`         | `false`        | okokBanking-Konto für die Gebühr. `false` = das Geld verschwindet aus der Wirtschaft |
| `Donations.Minimum` / `Maximum`     | `10` / `50000` | Grenzen einer einzelnen Spende                                                  |
| `Streams.MaxViewersPerStream`       | `5`            | Zuschauer pro Stream (siehe unten)                                              |
| `Streams.PauseTimeoutSeconds`       | `180`          | So lange darf die Kamera aus sein, bevor der Stream endet                       |
| `Streams.Video`                     | 960×540, 30 fps, 1500 kbit/s | Qualität des Streams                                              |
| `Voice.Mode`                        | `'talking'`    | `'talking'`, `'always'` oder `'off'`                                            |
| `Accounts.MaxAccountsPerCharacter`  | `3`            | Wie viele Konten ein Charakter anlegen darf                                     |

Das Staatskonto muss in okokBanking existieren. Beim Start schreibt Snitch eine
Warnung in die Konsole, wenn es fehlt.

## Wie das Streaming funktioniert

```
Streamer                          FiveM-Server                       Zuschauer
Sky-Phone-Kamera (Export)   ──►   Anmeldung, Chat, Spenden,   ◄──    App im Handy
unsichtbare Snitch-Seite:         Vermittlung der Verbindung         (Video, Chat)
Spielbild + Mikrofon        ════════ WebRTC, direkt (P2P) ════════►
```

- Die Kamera kommt von Sky Phone (`EnableWalkableCamera`). Der Spieler ist in der
  Ego-Perspektive, der eigene Körper und das HUD sind ausgeblendet.
- Eine unsichtbare Seite der Resource greift das Spielbild ab. Sie nutzt dafür
  denselben Mechanismus wie Sky Phone und `screenshot-basic`. Handy und andere
  NUI-Seiten sind nicht im Bild.
- Das Mikrofon läuft über die unsichtbare Seite, weil Sky Phone dem App-Fenster
  kein Mikrofon-Recht gibt. Bei `Voice.Mode = 'talking'` wird nur gesendet, während
  der Spieler im Spiel spricht. Spielgeräusche lassen sich technisch nicht abgreifen.
- **Handy zu = Stream pausiert.** Sky Phone schaltet die Kamera ab, sobald das Handy
  geschlossen wird. Zuschauer sehen dann „Gleich zurück“. In der App gibt es
  „Kamera wieder einschalten“. Nach `PauseTimeoutSeconds` endet der Stream.
- **P2P-Grenze:** Der Streamer schickt jedem Zuschauer eine eigene Kopie.
  Bei 1,5 Mbit/s und 5 Zuschauern sind das etwa 7,5 Mbit/s Upload, und jede
  Verbindung kostet CPU. Deshalb gibt es eine Zuschauergrenze. Die Anbindung an
  Cloudflare (ein Upload, beliebig viele Zuschauer) ist für Phase 2 geplant.

## Leistung

- Ohne laufenden Stream verbraucht Snitch fast nichts. Es gibt keine Dauerschleifen.
  Die Startseite fragt alle 10 Sekunden die Liste ab, aber nur solange sie offen ist.
- Beim Streamen läuft nur eine Schleife alle 100 ms, die prüft, ob der Spieler
  spricht. Das Spielbild wird mit 30 fps in 960×540 abgegriffen.
- Der Chat geht gebündelt alle 250 ms raus, Zuschauerzahlen alle 2 Sekunden.
- Vorschaubilder sind ein JPEG pro Minute mit 320×180 Pixeln (ca. 10–15 KB). Sie
  liegen nur im Arbeitsspeicher des Servers, nicht in der Datenbank.

## Getestet und nicht getestet

Automatisch getestet ist:
- **Server-Logik ohne FiveM:** `tests/server_flow_test.lua` spielt Konten, Streams,
  Chat, Vermittlung der Verbindung, Spenden mit Gebühr und Steuer, offene
  Auszahlungen und Stream-Ende durch.
- **Oberfläche im Browser** mit Testdaten. Die Videoverbindung läuft dabei über
  echtes WebRTC zwischen zwei Browser-Verbindungen.

**Noch nicht in FiveM getestet:** das Abgreifen des Kamerabilds, Mikrofon-Rechte,
WebRTC zwischen echten Spielern in verschiedenen Netzwerken sowie die Buchungen in
ESX und okokBanking. Vor dem Live-Betrieb also mit zwei Spielern ausprobieren.

## Fehlersuche

- **App erscheint nicht im App Store:** Startet Snitch nach Sky Phone? Die
  F8-Konsole zeigt `[snitch] Could not register with Sky Phone: …` mit dem Grund.
- **„Das Kamerabild konnte nicht abgegriffen werden“:** Der FiveM-Client hat der
  unsichtbaren Snitch-Seite kein Spielbild geliefert. Die genaue Meldung steht in
  der NUI-Konsole (F8 → `nui_devtools`).
- **Stream ohne Ton:** Das Mikrofon wurde nicht freigegeben, oder `Voice.Mode` steht
  auf `'off'`. Mit `'talking'` geht der Ton nur raus, während der Spieler im Spiel
  spricht.
- **Zuschauer bleibt bei „Verbinde …“ hängen:** Manche Heimnetze lassen keine
  direkte Verbindung zu. Abhilfe schafft ein TURN-Server, der ebenfalls für Phase 2
  geplant ist.
- **Steuern kommen nicht an:** Den Namen in `Donations.StateAccount` mit
  okokBanking vergleichen.

## Lizenz und Weitergabe

Snitch nutzt nur die öffentlichen Exports und das dokumentierte App-Protokoll von
Sky Phone. Code aus Sky Phone ist nicht enthalten.
