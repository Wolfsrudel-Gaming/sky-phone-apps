# Shadow – anonymes Untergrund-Board für Sky Phone

Shadow ist eine illegale App für Kriminelle im RP. Spieler finden sich dort
anonym, ohne die Nummer oder Dark-ID der anderen zu kennen. Das ist der
Unterschied zum eingebauten DarkChat von Sky Phone, der nur zwischen Leuten
funktioniert, die sich schon kennen.

## Funktionen

- **Versteckte Freischaltung:** Die App ist auf keinem Handy und nicht im App Store.
  - Man muss an einen der geheimen Punkte (`Config.UnlockPoints`) gehen, `E` drücken
    und ein paar Sekunden stehen bleiben.
  - Freigeschaltet wird das **Handy**, nicht der Charakter. Wer ein anderes Handy
    nutzt, hat die App dort nicht.
  - Die Punkte haben keinen Marker und keinen Blip. Wo sie sind, spricht sich im RP herum.
- **Kanäle:** offene Kanäle wie Aufträge, Waffen, Ware, Fahrzeuge, Infos (in der Config
  anpassbar). Ein grüner Punkt zeigt Aktivität in den letzten 15 Minuten.
- **Anzeigen:** Ein Beitrag kann als Anzeige markiert werden. „Privat antworten“
  startet einen anonymen Privatchat mit dem Verfasser.
- **Decknamen:**
  - `'custom'`: Spieler wählen ihren Decknamen selbst. Er muss eindeutig sein und
    lässt sich alle 24 h ändern.
  - `'random'`: Shadow würfelt Decknamen aus den Wortlisten in der Config.
- **PIN-Sperre:** optional, 4–6 Ziffern. Die App sperrt sich bei jedem Schließen.
  - Nach 5 Fehlversuchen ist sie 10 Minuten gesperrt.
  - Nach der 3. Sperre in Folge löscht sie sich selbst vom Handy.
- **Polizei:** Beamte (`Config.Police.Jobs`) können ein beschlagnahmtes Handy ohne
  PIN auswerten. Das dauert 60 Sekunden und gibt dann nur Lesezugriff auf Kanäle
  und alle Privatchats dieses Handys. Wurde die App vorher per Fehl-PIN gelöscht,
  gibt es nichts mehr zu finden.
- **Spuren verwischen:** Alle Nachrichten verschwinden nach 72 Stunden.

## Für Admins

Für Spieler ist Shadow anonym. In der Datenbank steht bei jeder Nachricht aber
der Charakter (`shadow_messages.author_identifier`), damit Regelverstöße
nachvollziehbar bleiben.

## Installation

```cfg
ensure oxmysql
ensure es_extended
ensure sky_phone
ensure shadow
```

Den Ordner `shadow` nach `resources/` kopieren. Die Tabellen `shadow_*` werden
automatisch angelegt.

**Wichtig:** Die Freischalt-Punkte stehen in `config.lua`. Diese Datei wird an die
Clients geschickt, wer will, kann sie dort finden. Bei Servern mit vielen
Datamining-Spielern sollten die Punkte regelmäßig verlegt werden.

## Getestet

`tests/shadow_flow_test.lua` spielt die Server-Logik ohne FiveM durch:
Freischaltung nur am Punkt, Decknamen, Kanäle, Anzeigen, Privatchats, PIN,
Sperre, Selbstlöschung und Polizei-Auswertung. Die Oberfläche lief im Browser
mit Testdaten. **In FiveM ist Shadow noch nicht getestet.**
