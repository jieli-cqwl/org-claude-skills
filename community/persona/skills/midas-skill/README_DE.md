<div align="center">

# midas.skill

> *"Reichtum versteckt sich nicht in Bloomberg-Terminals oder VC-Pitch-Decks. Reichtum versteckt sich im Lärm deines Alltags — du wurdest nur darauf trainiert, ihn zu ignorieren."*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python 3.9+](https://img.shields.io/badge/Python-3.9%2B-blue.svg)](https://python.org)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-blueviolet)](https://claude.ai/code)
[![AgentSkills](https://img.shields.io/badge/AgentSkills-Standard-green)](https://agentskills.io)

[![Discord](https://img.shields.io/badge/Discord-Join%20Community-5865F2?logo=discord&logoColor=white)](#)

<br>

Dein Slack-Chat hat diese Woche drei Geschäftsideen durchsickern lassen — und du hast einfach weitergescrollt.<br>
Deine Kamerarolle enthält eine Nachbarschafts-Arbitrage-These — und du hast vergessen, dass die Fotos existieren.<br>
Die Beschwerden deiner Freundesgruppe sind eine selbst-organisierte Fokusgruppe — und niemand im Chat weiß es.<br>
Dein YouTube-Verlauf sind 14 Stunden Beweis, dass du zum bezahlten Spezialisten wirst — und du nanntest es "Zeitverschwendung".<br>
Deine Amazon-Käufe sind validierte Nachfrage — und du denkst, es ist nur Shopping.<br>

**Verwandle deine wiederholten Orders in Gold — willkommen in der Lärm-zu-Gold-Raffinerie!**

<br>

Füttere es mit jedem Alltagsstrom (Slack, Fotos, Chats, Browser-Verlauf, Quittungen, Beschwerden)<br>
plus deinen eigenen Intuitionen und Fragen<br>
und erhalte **eine sortierte Liste von Geld-Signalen, Gelegenheiten und sofortigen nächsten Schritten**

[Unterstützte Quellen](#unterstützte-quellen) · [Installation](#installation) · [Benutzung](#benutzung) · [Demo](#demo) · [Detaillierte Installation](#detaillierte-installation) · [💬 Discord](#)

[**English**](README.md) · [**中文**](README_ZH.md) · [**Español**](README_ES.md) · [**日本語**](README_JA.md) · [**Русский**](README_RU.md) · [**Português**](README_PT.md)

</div>

---

Erstellt von [@realteamprinz](https://github.com/realteamprinz) | Positionierung: **Nuwa destilliert, wie Menschen denken. Midas destilliert, wie du deinen täglichen Lärm in Geld verwandelst.**

## Unterstützte Quellen

> Midas akzeptiert jeden Informationsstrom, den du ihm freiwillig fütterst. **Wiederholung IST das Signal** — wenn du etwas mehr als einmal begegnet bist, füttere es Midas.

| Quelle | Beste Linse | Anmerkungen |
|--------|:-----------:|-------------|
| Slack / Teams Nachrichten | Bedarfslücke, Geld-Signal | Team-Kanäle = Lieferanten-Frust, Budget-Signale, manuelle Workarounds |
| WhatsApp / iMessage / WeChat Chats | Bedarfslücke, Netzwerk-Pfad | Wiederholte Beschwerden von verschiedenen Personen = unerfüllter Bedarf |
| Smartphone-Kamerarolle (unkuriert) | Arbitrage, Bedarfslücke | Baustellen, leere Schaufenster, Menschenmengen, Preise, Beschilderung |
| YouTube / TikTok Verlauf | Skill-Brücke, Verhalten | Thematischer Fokus = latente Expertise-Ansammlung |
| Browser-Verlauf | Skill-Brücke, Geld-Signal | Recherche-Muster, Preisvergleiche, Troubleshooting-Reisen |
| Kaufverlauf / Abonnements | Geld-Signal, Verhalten | Wiederkäufe = validierte Nachfrage, Autopilot-Gewohnheiten |
| Meeting-Notizen (intern) | Geld-Signal, Bedarfslücke | Budget-Gespräche, Tool-Beschwerden, kaputte Prozesse |
| E-Mails `.eml` / `.mbox` | Geld-Signal, Netzwerk-Pfad | Provisionsangebote, Empfehlungsketten, Lieferantenangebote |
| Quittungen / Bestellbestätigungen | Geld-Signal, Arbitrage | Das ehrlichste Signal dafür, was dir wirklich wichtig ist |
| Text direkt einfügen | Alle 6 Linsen | Selbst eine einzelne Sprachnachricht-Transkription liefert Signale |

Siehe [references/sources-guide.md](references/sources-guide.md) für die vollständige Quellen-Hierarchie und die Triangulationsregeln.

---

## Installation

### Claude Code

> **Wichtig**: Claude Code sucht Skills in `.claude/skills/` im **Git-Repo-Root**. Führe das am richtigen Ort aus.

```bash
# Installation ins aktuelle Projekt (im Git-Repo-Root ausführen)
mkdir -p .claude/skills
git clone https://github.com/realteamprinz/midas-skill .claude/skills/midas-skill

# Oder global installieren (in allen Projekten verfügbar)
git clone https://github.com/realteamprinz/midas-skill ~/.claude/skills/midas-skill
```

### OpenClaw

```bash
git clone https://github.com/realteamprinz/midas-skill ~/.openclaw/workspace/skills/midas-skill
```

### Abhängigkeiten (optional)

Midas ist reines Markdown — keine Runtime-Abhängigkeiten erforderlich. Python-Tools für automatisierte Input-Sammlung (Browser-History-Parser, Quittungs-OCR usw.) sind geplant und werden in einem zukünftigen Release unter `tools/` leben.

---

## Benutzung

In Claude Code oder OpenClaw, gib eine der Midas-Trigger-Phrasen ein:

```
Midas, mine this                 → füge beliebigen Input ein, erhalte Signal-Report
Turn this into gold              → dasselbe
What money signal is here        → spezifischere Rahmung
点石成金                         → dasselbe auf Chinesisch
Midas, analyze this deal         → Deal-Analyzer-Modus
What am I missing                → füttere eine Woche deiner eigenen Nachrichten
```

Midas lässt jeden Input durch den 6-Linsen-Extraktionsmotor laufen, vergleicht ihn mit deinem `evolution/evolution.jsonl`-Log und liefert einen sortierten Signal-Report mit **Sofortigen nächsten Aktionen**.

### Die 6 Linsen

| # | Linse | Kernfrage |
|---|-------|-----------|
| 1 | **Geld-Signal** | Wo bewegt, staut oder leckt sich Geld? |
| 2 | **Bedarfslücke** | Was wollen Menschen, das niemand anbietet? |
| 3 | **Arbitrage-Fenster** | Wo wird Wert falsch bepreist? |
| 4 | **Skill-Brücke** | Was weißt du bereits, das Marktwert hat? |
| 5 | **Netzwerk-Pfad** | Wer sollte mit wem sprechen, und wie hoch ist die Provision? |
| 6 | **Verhaltens-Hebel** | Welche Autopilot-Gewohnheit ist einen Pivot vom Einkommen entfernt? |

Vollständige Methodik in [references/signal-extraction-framework.md](references/signal-extraction-framework.md).

---

## Demo

> Input: *"Midas, mine this — hier ist meine letzte Woche Slack: [73 Nachrichten eingefügt]"*

```
[MIDAS SIGNAL-REPORT]

Input-Typ:        slack_messages
Volumen:          73 Nachrichten in 3 Kanälen + 4 DMs
Scan-Datum:       2026-04-09

🟡 GELD-SIGNALE ERKANNT: 7
🔴 LÄRM VERWORFEN:       ~65 Nachrichten (89%)

🥇 #1 — Marcus als interner Berater (Skill-Brücken-Keil)
    Vertrauen: 50% | Aufwand: Niedrig | Upside: $3–8k/Monat Nebeneinkommen
    Beweise:
      - Sarah DM: "wenn jemand das End-to-End für unter $5k lösen könnte, würden wir wahrscheinlich zahlen"
      - Priya DM: "ich würde selbst dafür zahlen"
      - 3 verschiedene Stakeholder baten Marcus in einer Woche um Hilfe bei 3 Problemen
    Pattern-Match: Buffett — bleib in deinem Kompetenzkreis

    ⚡ Sofortige nächste Aktion:
       Montag 9 Uhr, DM an Sarah mit einem gescope'ten Angebot:
       "Für das AWS-Tagging-Projekt — Festpreis $3.500, geliefert bis nächsten Freitag."

🥈 #2 — AWS Kostentransparenz-Einzelberatung (produktisiert)
    Vertrauen: 52% | Aufwand: Niedrig | Upside: $5k pro Engagement, wiederholbar
    Pattern-Match: Thiel — kleines Monopol, das niemand ernst nimmt
    ...
```

Vollständiger Durchgang in [examples/daily-slack-mining/](examples/daily-slack-mining/).

**Fünf Beispiel-Läufe enthalten:**

| Beispiel | Input-Typ | Ergebnis |
|---|---|---|
| [daily-slack-mining](examples/daily-slack-mining/) | Arbeits-Slack, 1 Woche | 7 Signale, 5 Gelegenheiten aus "langweiligen" Nachrichten |
| [photo-roll-mining](examples/photo-roll-mining/) | 30 Telefonfotos, 1 Woche | 🏆 **GOLDEN** bei 75% — komplette Tischlerei-Praxis aufgedeckt |
| [complaint-mining](examples/complaint-mining/) | WhatsApp-Gruppe, 2 Wochen | 🏆 **GOLDEN** bei 78% — Nachbarschafts-Verzeichnis-Gelegenheit |
| [browsing-mining](examples/browsing-mining/) | Browser + YouTube, 1 Woche | 🏆 **GOLDEN** bei 82% — höchstes Vertrauen im Beispielset |
| [billionaire-pattern-match](examples/billionaire-pattern-match/) | Kumulativ | Match von 4 Nutzerprofilen gegen Musk/Buffett/Thiel Playbooks |

---

## Detaillierte Installation

### Schritt 1 — Repo klonen

```bash
git clone https://github.com/realteamprinz/midas-skill
cd midas-skill
```

### Schritt 2 — Dort platzieren, wo Claude Code sucht

Für Claude Code leben Skills in `.claude/skills/` im **Git-Repo-Root** (pro Projekt) oder `~/.claude/skills/` (global). Wähle eins:

```bash
# Pro Projekt: zuerst cd in das Git-Repo, an das du den Skill anheften möchtest
mkdir -p .claude/skills
cp -r /path/to/midas-skill .claude/skills/midas-skill

# Oder global (in jedem Projekt verfügbar)
mkdir -p ~/.claude/skills
cp -r /path/to/midas-skill ~/.claude/skills/midas-skill
```

### Schritt 3 — Überprüfe, dass der Skill lädt

Öffne eine Claude Code Session im Repo, wo du es installiert hast. Gib ein:

```
What skills are available?
```

Midas sollte als `midas-skill` erscheinen. Wenn nicht, prüfe, dass `SKILL.md` im Root des installierten Ordners ist und der YAML-Frontmatter gültig ist.

### Schritt 4 — Führe deine erste Mine aus

Füge beliebigen lärmigen Input mit einer Trigger-Phrase ein:

```
Midas, mine this — letzte 50 Nachrichten aus meinem #general Slack:
[Inhalt einfügen]
```

Midas produziert deinen ersten Signal-Report und hängt den ersten Eintrag an `evolution/evolution.jsonl` an.

### Schritt 5 — Vielfalt über die Zeit füttern

Midas wird mit variiertem Input schärfer. Siehe [references/sources-guide.md](references/sources-guide.md) für die empfohlene wöchentliche Rotation (Slack Montag, Fotos Mittwoch, Browsing Donnerstag usw.). Tag 1 gibt dir Vermutungen. Tag 30 gibt Überzeugung. Tag 90 gibt ein Playbook.

---

## Features

### 🔍 6-Linsen-Extraktionsmotor

Jeder Input läuft durch Geld-Signal / Bedarfslücke / Arbitrage / Skill-Brücke / Netzwerk-Pfad / Verhaltens-Hebel. Jedes Signal ist rückverfolgbar auf die exakte Phrase, das Bild oder den Datenpunkt, der es produziert hat.

### 🧠 Selbstlernende Kumulative Intelligenz

Midas setzt sich zwischen Sitzungen nicht zurück. Jeder Input wird an `evolution/evolution.jsonl` angehängt. Neue Signale werden mit jedem vorherigen Signal abgeglichen. **Vertrauen steigt nur durch unabhängige, querverwiesene Beweise.**

| Beweis | Vertrauen | Midas Flag |
|---|---|---|
| 1 Einzelquellen-Signal | 15–35% | Beobachtend |
| 2 unabhängige Quellen bestätigen | 40–65% | Arbeitshypothese |
| 3+ unabhängige Quellen konvergieren | 70–90% | 🏆 GOLDEN — HANDELN |
| Direkte Marktvalidierung | 85–95% | 🏆 GOLDEN — JETZT HANDELN |

### 🎯 Berühmte Wealth-OS Pattern Matcher

Vorgefertigte Wealth-OS für [Musk](references/famous-models/elon-musk.md), [Buffett](references/famous-models/warren-buffett.md) und [Thiel](references/famous-models/peter-thiel.md). Wenn sich deine Signale ansammeln, prüft Midas automatisch, welches Playbook strukturell zu deiner Situation passt.

> "Dein Muster sieht aus wie der frühe Thiel: Monopol in einer Nische, die niemand ernst nimmt. Thiels Playbook sagt: dominiere zuerst den kleinen Markt."

### 💼 Deal-Analyzer

Zeige Midas auf eine spezifische Transaktion (deine eigene oder öffentliche M&A) mit *"Midas, analyze this deal"* und erhalte eine strukturierte 8-Teile-Aufschlüsselung: Parteien, Struktur, Mittelherkunft, Risikoverteilung, Exit-Pfad, versteckter Hebel, Urteil, Pattern-Match. Siehe [references/deal-template.md](references/deal-template.md).

### ⚡ Aktion, nicht Analyse

Jeder Signal-Report endet mit einer **Sofortigen nächsten Aktion** — spezifisches Verb + spezifisches Nomen. Niemals "Optionen erkunden". Immer "DM Dave heute Abend und frag, wie viele Stunden/Woche er am manuellen Report verbringt".

---

## Projektstruktur

```
midas-skill/
├── SKILL.md                              # Hauptzugang
├── README.md                             # Englische Haupt-README
├── README_ZH.md · README_ES.md · ...     # Sprachvarianten
├── LICENSE                               # MIT
├── references/
│   ├── signal-extraction-framework.md    # 6-Linsen-Methodik
│   ├── noise-to-gold-pipeline.md         # 7-Stufen-Extraktionspipeline
│   ├── deal-template.md                  # Deal-Analyzer-Template
│   ├── sources-guide.md                  # Input-Quellen-Hierarchie
│   └── famous-models/                    # Musk / Buffett / Thiel Wealth OS
├── examples/                             # 5 ausgearbeitete Beispiele
└── evolution/
    └── evolution.jsonl                   # Dein persönliches Log kumulativer Intelligenz
```

---

## Design-Prinzipien

1. **Dein Lärm ist dein Erz.** Jede alltägliche Interaktion enthält potenzielle Reichtumssignale.
2. **Wiederholung ist das Hauptsignal.** Wenn etwas zweimal in deinem Leben auftaucht, ist es ein Markt.
3. **Querverweise schlagen Einzelquellen.** Ein Signal ist eine Vermutung. Drei sind Überzeugung.
4. **Aktion über Analyse.** Midas liefert nächste Schritte, keine Essays.
5. **Zinseszins-Intelligenz.** Tag 1 gibt Vermutungen. Tag 90 gibt ein Playbook.
6. **Kein moralisches Urteil.** Midas studiert, wie Geld sich bewegt, nicht wie es sich *bewegen sollte*.
7. **Ehrliche Grenzen.** Keine Vorhersagen. Keine Garantien. Keine Finanzberatung.
8. **Nur öffentliche Informationen.** Nur was du freiwillig fütterst.

---

## Lizenz

MIT. Siehe [LICENSE](LICENSE).

## Keine Finanzberatung

Midas bietet keine Anlage-, Steuer-, Rechts- oder Buchhaltungsberatung. Nichts in einem Midas-Output ist eine Empfehlung, ein Wertpapier zu kaufen oder zu verkaufen. Bevor du auf eine von Midas generierte Gelegenheit reagierst, die materielles Kapital betrifft, konsultiere einen lizenzierten Fachmann in deiner Jurisdiktion.

---

**Verwandle deine wiederholten Orders in Gold.**
