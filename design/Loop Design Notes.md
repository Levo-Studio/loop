# Handoff: Loop — Study Timer (iOS / iPadOS)

## Overview
Loop ist eine minimalistische Study-Timer-App von Levo Studio. Vier Timer-Modi plus Einstellungen, alles fullscreen, ohne Navigation-Chrome. Marke: nüchtern, technisch-präzise, kein Wellness-Branding. Produktname ist **Loop**, Levo Studio erscheint nur als Anbieter (Footer der Einstellungen: „Loop · Levo Studio · Built in Germany").

## About the Design Files
Die Dateien in diesem Bundle sind **Design-Referenzen in HTML** — Prototypen, die Aussehen und Verhalten zeigen, kein Produktionscode zum Kopieren. Aufgabe ist, diese Designs in der Zielumgebung nachzubauen (SwiftUI ist für iOS/iPadOS der naheliegende Weg) und dabei die dort etablierten Patterns zu verwenden. Existiert noch keine Codebase, ist SwiftUI mit einem eigenen Theme-Layer die Empfehlung.

## Fidelity
**High-fidelity.** Farben, Typo, Abstände und Zustände sind final. Pixelgenaue Umsetzung erwartet; die HTML-Größen sind in Design-Punkten angegeben und lassen sich 1:1 als pt/dp übernehmen.

## Kernprinzip (nicht verhandelbar)
Eine einzige Fortschrittsanzeige: **eine Fläche, die von unten bündig hochsteigt**, proportional zu verstrichener Zeit / Gesamtdauer des aktuellen Blocks. Keine zusätzlichen Balken, Ringe, Dots oder Segmente. Bei Intervall gilt derselbe Fill-Style für Fokus-Block und Pause; nur Status-Label und Rundenzähler ändern sich.

**Zweifarbige Typo an der Füllkante:** Alles, was die Kante schneidet (Zeit, Labels, Buttons, Nav-Punkte), ist oberhalb in Vordergrundfarbe (Tinte), unterhalb im On-Fill-Ton. Technisch im Prototyp: identischer Inhalt zweimal gerendert, die zweite Ebene mit `clip-path: inset(<100 − fill>% 0 0 0)` und On-Fill-Farbe. In SwiftUI äquivalent über zwei Text-Layer mit `mask` auf das Fill-Rechteck, oder `.blendMode` auf einem Overlay.

## Navigation
Fünf Seiten, horizontal per Swipe, in dieser Reihenfolge:
1. Uhr · 2. Count-up · 3. Countdown (einfach) · 4. Intervall · 5. Einstellungen

Immer sichtbar: fünf Punkte unten mittig (aktiv 7 pt, inaktiv 6 pt bei 30 % Deckkraft, Abstand 9 pt, 16 pt Abstand nach oben). Das ist die einzige Navigation — keine Tab-Bar, keine Titelleiste, keine Buttons zum Moduswechsel.

## Screens / Views

Alle Screens teilen das Grundgerüst (iPhone Portrait, 372 × 805 pt Referenz):
- Padding: 48 pt oben, 28 pt seitlich, 32 pt unten (Landscape 32/28/24; iPad 52/40/34 bei Faktor 1.15 und zentrierter 520-pt-Inhaltsspalte)
- Vertikale Struktur: Status-Pille oben → Zeitblock (flex: 1, zentriert, `margin-top: −30 pt`) → Steuerung → Nav-Punkte

### 1 Uhr
Zeigt die aktuelle Uhrzeit, Sekunden per Einstellung zu- oder abschaltbar. Pille „Uhr", darunter Zeit (bei 8 Zeichen automatisch kleiner, siehe Typo-Regel), Sekundärzeile mit Wochentag und Datum. Keine Steuerung, keine Fläche.

### 2 Count-up (Stoppuhr)
States: **Idle** (00:00, „bereit", Start / Reset deaktiviert) · **Running** (laufende Zeit, „seit 09:29", Pause / Reset) · **Paused** („angehalten", Weiter / Reset). Keine Fläche — es gibt keine Gesamtdauer, also keinen Fortschritt.

### 3 Countdown einfach
- **Idle**: große Vorschauzeit (76 pt), darunter Skalen-Slider „Dauer" 0–60 min. Skala: Strich je Minute (8 pt hoch, 25 % Deckkraft), großer Strich alle 5 min (17 pt, 55 %), Zahl alle 15 min. Marker: 3 pt breiter, 30 pt hoher Balken im Akzent. Steuerung: Start / Reset (deaktiviert).
- **Running**: Fläche 25 %, Zeit 18:42, „von 25:00", Pause / Stop.
- **Paused**: Fläche eingefroren, Pille „Countdown · pausiert", Weiter / Stop.
- **Finished**: Fläche 100 %, Pille „Fertig", 00:00, „25:00 abgeschlossen", Neu starten / Schließen.

### 4 Intervall
- **Setup**: zwei Skalen-Slider — Fokus 0–60 min (Zahlen alle 15), Pause 0–30 min (Zahlen alle 10) — darunter Trennlinie, dann Runden mit − / + Steppern (29 pt Kreise, 1 pt Rand), darunter „Gesamt 2:00 h". Keine Presets bei den Runden. Steuerung: Start / Reset.
- **Running Fokus**: Fläche 25 %, Pille „Fokus · Runde 02 / 04", 18:42, „von 25:00", Pause / **Skip deaktiviert** (Fokus-Block ist nicht überspringbar).
- **Running Pause**: Fläche 54 %, Pille „Pause · Runde 02 / 04", 02:18, „von 05:00", Pause / **Skip aktiv**.
- **Paused**: Fläche eingefroren (Beispiel 45 %), Pille „Pausiert · Fokus · 02 / 04", Weiter / Stop.
- **Finished**: Fläche 100 %, Pille „Fertig · 4 von 4", „2:00 Stunden fokussiert", Neu starten / Schließen.

Der Statusindikator zeigt in jedem laufenden State, ob Fokus oder Pause aktiv ist, plus Runde x von y.

### 5 Einstellungen
Überschrift „Einstellungen", Toggle „Sekunden in der Uhr" (50 × 29 pt Pille im Akzent, Knopf 23 pt in Hintergrundfarbe), Trennlinie, Abschnitt „Akzentfarbe" mit vier Zeilen (Swatch 20 pt, Radius 6 pt; aktive Zeile mit 1.5 pt Akzentrahmen und „Aktiv"-Marker). Footer: „Loop · Levo Studio · Built in Germany".

## Design Tokens

### Typografie
IBM Plex Mono durchgängig — 300 für die große Zeit, 500 für Labels und Buttons, 400 sonst.

| Rolle | Größe (iPhone Portrait) | Details |
|---|---|---|
| Zeit groß | 104 pt | line-height .82, letter-spacing −.055em, tabular-nums, weight 300 |
| Zeit Landscape | 84 pt | gleiche Regeln |
| Zeit-Autoskalierung | × min(1, 5 / Zeichenzahl) | „09:41:07" (8 Zeichen) → 65 pt |
| Countdown-Vorschau (Idle) | 76 pt | weight 300 |
| Status-Pille | 11 pt | letter-spacing .14em, uppercase, weight 500 |
| Sekundärzeile unter der Zeit | 11 pt | letter-spacing .18em, uppercase, Deckkraft 62 % |
| Abschnittsüberschrift | 11 pt | letter-spacing .2em, uppercase, Deckkraft 62 % |
| Buttons | 12 pt | letter-spacing .12em, uppercase, weight 500 |
| Slider-Wert | 15 pt, Einheit 10 pt | tabular-nums |
| Stepper-Wert | 19 pt | tabular-nums |
| Settings-Zeile | 14 pt | letter-spacing −.01em |
| Footer | 10 pt | letter-spacing .16em, uppercase, Deckkraft 40 % |

iPad: alle Werte × 1.15, Inhalt in zentrierter Spalte von 520 pt.

### Farben — Akzente (vom Nutzer wählbar, Default Petrol)
Ein Hue pro Akzent; Light und Dark nutzen davon zwei Helligkeiten, nie zwei verschiedene Farben.

| Akzent | Fill Light | Fill Dark | Marker Light | Marker Dark |
|---|---|---|---|---|
| Petrol (Default) | `oklch(0.55 0.09 205)` | `oklch(0.40 0.08 205)` | `oklch(0.55 0.09 205)` | `oklch(0.68 0.10 205)` |
| Bernstein | `oklch(0.72 0.125 72)` | `oklch(0.48 0.10 72)` | `oklch(0.72 0.125 72)` | `oklch(0.75 0.125 72)` |
| Flieder | `oklch(0.58 0.105 305)` | `oklch(0.41 0.09 305)` | `oklch(0.58 0.105 305)` | `oklch(0.65 0.105 305)` |
| Graphit | `oklch(0.34 0.008 250)` | `oklch(0.70 0.008 250)` | gleich Fill | gleich Fill |

### Farben — Grund und Schrift je Akzent

| Akzent | BG Light | BG Dark | FG Light | FG Dark |
|---|---|---|---|---|
| Petrol | `#f1f5f4` | `#0d1213` | `#111a1b` | `#e6f0f0` |
| Bernstein | `#f6f4ee` | `#12110c` | `#1a1710` | `#f2ecdf` |
| Flieder | `#f4f2f6` | `#100e13` | `#17141b` | `#ece8f2` |
| Graphit | `#f4f4f3` | `#0f1011` | `#16171a` | `#eceded` |

**On-Fill-Regel:** Ist die Fill-Lightness > 0.62 (Bernstein Light, Graphit Dark), ist die Schrift auf der Fläche `#141414`, sonst `#f6fbfb`. Nicht raten — Regel implementieren, damit sie für jeden Akzent automatisch stimmt.

### Abgeleitete Töne (aus FG mit Alpha)
- `hair` = FG @ 15 % — Trennlinien, inaktive Rahmen
- `chip` = FG @ 8 % — Status-Pille
- `chipStrong` = FG @ 12 % — Primärbutton-Fläche
- `hairStrong` = FG @ 26 % — Sekundärbutton-Rahmen, Stepper-Kreise
- Im On-Fill-Layer werden dieselben Alphas auf den On-Fill-Ton angewendet.

### Radien und Maße
- Buttons und Pillen: vollrund (999)
- Settings-Akzentzeilen: 13 pt, Swatch 6 pt
- Stepper-Kreise: 29 pt Durchmesser
- Button-Höhe: 15 pt Innenabstand oben/unten (≈ 50 pt gesamt), Reihe mit 10 pt Gap
- Keine Schatten, keine Verläufe

## Interactions & Behavior
- **Seitenwechsel**: horizontaler Swipe zwischen den fünf Seiten, Punkte folgen. Kein Wrap-around.
- **Fläche**: animiert kontinuierlich mit dem Timer (linear, keine Federung). Beim Pausieren friert sie ein, beim Fortsetzen läuft sie weiter. Bei Blockwechsel im Intervall springt sie auf 0 und steigt neu.
- **Skip**: nur in der Pause aktiv; überspringt zum nächsten Fokus-Block. Im Fokus-Block ist der Button sichtbar, aber deaktiviert (45 % Deckkraft) — er verschwindet nicht, damit das Layout ruhig bleibt.
- **Intervall-Ablauf**: Fokus → Pause → Fokus → Pause … bis alle Runden durch sind, danach automatisch der Finished-Screen. Keine Pause nach der letzten Runde.
- **Reset**: setzt den Timer auf den Setup-Zustand der jeweiligen Seite zurück.
- **Slider**: Drag über die Skala, Rasterung auf ganze Minuten, haptisches Feedback bei jedem Rastpunkt empfohlen.
- **Stepper**: Runden 1–99, Tap ändert um 1.
- **Display**: Bildschirm bleibt an, solange ein Timer läuft.

## State Management
- `page: 0…4` (Uhr, Count-up, Countdown, Intervall, Settings)
- `showSeconds: Bool` (Uhr)
- `countUp: { elapsed, running }`
- `countdown: { duration, remaining, phase: idle | running | paused | finished }`
- `interval: { focusMin, breakMin, rounds, currentRound, blockType: focus | break, remaining, phase: setup | running | paused | finished }`
- `accent: petrol | bernstein | flieder | graphit`
- Fortschritt der Fläche = 1 − remaining / blockDuration, immer bezogen auf den **aktuellen** Block.
- Timer-Zustand über App-Neustart und Hintergrund hinweg persistieren (Endzeitpunkt speichern, nicht Ticks zählen).

## Assets
- App-Icon: „Block-Loop" — gerundetes Quadrat als Ring, einfarbig, kein Buchstabe. Auf 1024 × 1024: Zeichen 708 × 708 zentriert, Rahmenstärke 149, Eckradius 214, Farbe `oklch(0.68 0.10 205)`, Hintergrund transparent. PNG-Export (1024 / 512 / 180) liegt im File `Loop Icon.dc.html`.
- Keine weiteren Bilder oder Icons in der App.

## Files
- `Loop Icon.dc.html` — App-Icon, Größenvorschauen, PNG-Export
- `Loop iPhone Screens.dc.html` — alle States, Hoch- und Querformat, Light und Dark, plus Akzentvarianten
- `Loop iPad Screens.dc.html` — dieselben States für iPad Air 11″ (1640 × 2360 und 2360 × 1640)
- `Levo Timer - Directions.dc.html` — Entwurfshistorie der Designrichtungen, nur als Kontext
