# Planer einrichten – Schritt für Schritt (ohne Vorkenntnisse)

> Diese Anleitung wurde – wie das ganze Projekt – mit Künstlicher Intelligenz (Claude) geschrieben.

Du brauchst **keine Programmierkenntnisse**. Plane etwa **eine Stunde** ein. Wenn ein Begriff
unbekannt ist: Am Ende gibt es ein kleines [Wörterbuch](#wörterbuch).

---

## Worum geht es?

Planer ist eine App für Aufgaben und Termine. Damit deine Aufgaben auf iPhone, iPad und Mac
gleich sind, müssen sie irgendwo gespeichert werden. Bei den meisten Apps passiert das auf
Computern einer Firma („Cloud“). Bei Planer passiert es **auf einem kleinen Computer bei dir zu
Hause**. Niemand außer dir kommt an die Daten.

Dieser kleine Computer heißt in der Anleitung **Server**. Am einfachsten ist ein
**Raspberry Pi** – ein günstiger Mini-Computer in der Größe einer Zigarettenschachtel, der
kaum Strom verbraucht und einfach immer eingeschaltet bleibt.

```
 iPhone ─┐
 iPad   ─┼──►  Raspberry Pi bei dir zu Hause  ──►  speichert deine Aufgaben
 Mac    ─┘
```

Übrigens: **Die App funktioniert auch ganz ohne Server.** Dann bleiben die Aufgaben nur auf dem
einen Gerät. Den Server brauchst du nur, wenn mehrere Geräte dieselben Aufgaben zeigen sollen.

---

## Was du brauchst

| Was | Wozu | Ungefähre Kosten |
| --- | --- | --- |
| Raspberry Pi 4 oder 5 (2 GB Speicher reichen) | wird dein Server | 50–80 € |
| Passendes Netzteil für den Pi | Strom | 10 € |
| microSD-Karte, mindestens 16 GB | darauf kommt das Betriebssystem | 10 € |
| Einen Computer (Mac oder Windows) mit SD-Karten-Leser | zum Einrichten | vorhanden |
| WLAN oder ein Netzwerkkabel zum Router | damit der Pi ins Netz kommt | vorhanden |
| iPhone, iPad und/oder Mac | darauf läuft die App | vorhanden |

Statt eines Raspberry Pi geht auch jeder andere Computer mit Linux, der dauerhaft läuft. Die
Anleitung geht aber vom Raspberry Pi aus.

---

## Schritt 1: Die App installieren

Lade **„Planer – Aufgaben & Kalender“** kostenlos aus dem App Store:
👉 <https://apps.apple.com/de/app/id6834079614>

Das geht auf iPhone und iPad. Die Mac-Version wird gerade von Apple geprüft. Bis dahin
kannst du sie selbst auf deinen Mac spielen – siehe [Anhang: App selbst bauen](#anhang-app-selbst-bauen).

Öffne die App einmal. Du kannst sie sofort benutzen – der Server kommt jetzt dazu.

---

## Schritt 2: Den Raspberry Pi vorbereiten

Auf die microSD-Karte kommt jetzt das Betriebssystem des Pi (so etwas wie Windows, nur kostenlos
und für den Pi gemacht).

1. Lade auf deinem Computer das kostenlose Programm **Raspberry Pi Imager** herunter:
   <https://www.raspberrypi.com/software/> – und installiere es.
2. Stecke die microSD-Karte in deinen Computer.
3. Öffne den Raspberry Pi Imager und wähle nacheinander:
   - **Gerät:** dein Raspberry-Pi-Modell (z. B. „Raspberry Pi 5“)
   - **Betriebssystem:** „Raspberry Pi OS (other)“ → **„Raspberry Pi OS Lite (64-bit)“**
     (die Version ohne Bildschirm-Oberfläche – die brauchen wir nicht)
   - **Speicher:** deine microSD-Karte
4. Klicke auf **Weiter**. Der Imager fragt, ob du **Einstellungen anpassen** willst → **Ja / Einstellungen bearbeiten**.
   Trage Folgendes ein:
   - **Hostname:** `planer` (so heißt dein Pi später im Netzwerk)
   - **Benutzername und Passwort:** denk dir etwas aus und **schreib beides auf**
     (in dieser Anleitung heißt der Benutzer `ich`)
   - **WLAN:** Name und Passwort deines WLANs (nicht nötig, wenn du ein Netzwerkkabel nutzt)
   - **Land/Zeitzone:** Deutschland, Europe/Berlin
   - Reiter **Dienste:** **SSH aktivieren** und „Passwort zur Authentifizierung verwenden“ wählen
5. Speichern, bestätigen und warten, bis der Imager fertig ist (ein paar Minuten).
6. Karte aus dem Computer nehmen, in den Raspberry Pi stecken, (Netzwerkkabel anstecken, falls du
   eins nutzt) und **den Strom anschließen**. Der Pi startet von selbst.
7. **Warte 3–5 Minuten.** Beim ersten Start richtet er sich ein.

---

## Schritt 3: Mit dem Raspberry Pi verbinden

Der Pi hat keinen Bildschirm. Du steuerst ihn von deinem Computer aus, indem du Befehle eintippst.
Das klingt schwieriger, als es ist: Du kopierst die Befehle einfach aus dieser Anleitung.

**Ein Befehlsfenster öffnen:**

- **Mac:** Drücke `Cmd + Leertaste`, tippe `Terminal` und drücke Enter.
- **Windows:** Rechtsklick auf das Startmenü → **„Terminal“** oder **„Windows PowerShell“**.

**Verbinden** – tippe Folgendes ein (statt `ich` deinen Benutzernamen aus Schritt 2) und drücke Enter:

```bash
ssh ich@planer.local
```

- Beim ersten Mal kommt eine Frage mit „fingerprint“ → tippe `yes` und Enter.
- Dann wird nach dem **Passwort** gefragt. Tippe es ein und drücke Enter.
  **Beim Tippen erscheinen keine Zeichen – das ist normal!**

Wenn jetzt etwas wie `ich@planer:~ $` erscheint, bist du auf dem Pi. 🎉
Alle folgenden Befehle tippst du in dieses Fenster.

> **Klappt nicht?** Siehe [Probleme lösen](#probleme-lösen).

---

## Schritt 4: Den Planer-Server installieren

Kopiere diese drei Befehle nacheinander ins Fenster und drücke jeweils Enter. Wenn nach einem
Passwort gefragt wird, gib dein Pi-Passwort ein.

**1. Werkzeuge installieren** (dauert 1–3 Minuten):

```bash
sudo apt update && sudo apt install -y git python3
```

**2. Planer herunterladen:**

```bash
git clone https://github.com/Minipliy/planer.git
```

**3. Server einrichten:**

```bash
sudo bash planer/server/install.sh
```

Am Ende erscheint ein Kasten wie dieser:

```
 Fertig! Der Planer-Server läuft.

 Trage in der App unter Einstellungen > Synchronisation ein:
   Serveradresse:  http://planer.local:8788
   Token:          AbC123... (eine lange Zeichenfolge)
```

**Schreib dir Serveradresse und Token auf** (oder lass das Fenster offen). Das Token ist wie ein
Passwort für deinen Server – gib es nicht weiter.

Der Server startet ab jetzt **automatisch**, auch nach einem Stromausfall.

---

## Schritt 5: Die App mit dem Server verbinden

Auf **jedem** Gerät (iPhone, iPad, Mac):

1. Öffne Planer.
2. Tippe unten auf das **Zahnrad** (Einstellungen). Auf dem Mac/iPad ist das Zahnrad unten links.
3. Unter **Synchronisation** trägst du ein:
   - **Serveradresse:** die Adresse aus Schritt 4, z. B. `http://planer.local:8788`
   - **Token:** das Token aus Schritt 4
4. Tippe auf **„Speichern & synchronisieren“**.
5. Bei **Status** sollte nach ein paar Sekunden **„Synchronisiert“** stehen. Fertig!

Beim ersten Mal fragt das iPhone eventuell, ob Planer **Geräte im lokalen Netzwerk** finden darf →
**Erlauben**.

> Ab jetzt gleichen sich deine Geräte ab, **sobald sie im selben WLAN wie der Pi sind**.
> Unterwegs arbeitest du ganz normal weiter; die Änderungen werden übertragen, sobald du wieder
> zu Hause bist. Wenn du auch unterwegs abgleichen willst: Schritt 6.

---

## Schritt 6 (optional): Auch unterwegs abgleichen

Damit dein Handy den Pi auch von unterwegs erreicht, nutzen wir **Tailscale**. Das baut eine
verschlüsselte Verbindung zwischen deinen Geräten auf – so, als wären sie im selben WLAN.
Für private Nutzung ist es kostenlos, und du musst am Router nichts einstellen.

> **Wichtig:** Gib den Port 8788 **niemals** im Router frei („Portweiterleitung“). Dann wäre dein
> Server ungeschützt im Internet erreichbar. Tailscale ist der sichere Weg.
>
> Ehrlich gesagt: Tailscale ist eine Firma. Deine Aufgaben laufen aber **verschlüsselt** direkt
> zwischen deinen Geräten; Tailscale vermittelt nur die Verbindung. Wer gar keinen Anbieter
> möchte, kann stattdessen WireGuard oder Headscale selbst betreiben (das ist aber deutlich
> aufwendiger).

1. Lege auf <https://tailscale.com> ein kostenloses Konto an (z. B. mit deiner Apple-ID).
2. Installiere Tailscale **auf dem Pi** (im Befehlsfenster aus Schritt 3):

   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```

   Es erscheint ein Link. Öffne ihn im Browser und melde dich an – damit gehört der Pi zu
   deinem Tailscale-Konto.
3. Öffne im Browser die Tailscale-Verwaltung (<https://login.tailscale.com/admin/dns>) und schalte
   dort **MagicDNS** und **HTTPS Certificates** ein.
4. Mach den Planer-Server über Tailscale erreichbar (wieder auf dem Pi):

   ```bash
   sudo tailscale serve --bg 8788
   ```

   Es wird eine Adresse angezeigt, etwa `https://planer.dein-name.ts.net`. **Schreib sie auf.**
5. Installiere die **Tailscale-App** aus dem App Store auf iPhone, iPad und Mac und melde dich dort
   mit **demselben Konto** an.
6. Trage in Planer unter **Einstellungen → Synchronisation** die neue Adresse ein
   (`https://planer.dein-name.ts.net`, ohne `:8788`), das Token bleibt gleich →
   **„Speichern & synchronisieren“**.

Jetzt gleicht Planer überall ab, solange Tailscale auf dem Gerät eingeschaltet ist.

---

## Widgets einrichten (optional)

Planer hat Widgets – kleine Fenster mit deinen Aufgaben direkt auf dem Bildschirm, ohne die App zu öffnen.

**Kalender auf dem Home-Bildschirm:**
1. Auf dem Home-Bildschirm auf eine freie Stelle **lange drücken**, bis die Symbole wackeln.
2. Oben links auf **„Bearbeiten“** → **„Widget hinzufügen“** tippen.
3. Nach **„Planer“** suchen, das Widget **„Kalender & Heute“** wählen → **„Widget hinzufügen“**.

Links siehst du den Monat (mit den Pfeilen blätterst du), rechts deine Aufgaben für heute.
Überfällige Aufgaben stehen rot ganz oben.

**Nächste Aufgabe neben der Uhrzeit (Sperrbildschirm):**
1. iPhone sperren, dann den Sperrbildschirm **lange drücken** → **„Anpassen“** → **„Sperrbildschirm“**.
2. Auf das Feld **über der Uhrzeit** (dort steht das Datum) tippen.
3. **„Planer“** → **„Nächste Aufgabe“** wählen. Fertig.

Die Widgets aktualisieren sich automatisch, wenn du in der App etwas änderst.

---

## Im Alltag

Alle Befehle tippst du nach `ssh ich@planer.local` auf dem Pi ein.

**Token noch einmal anzeigen:**

```bash
sudo cat /var/lib/planer/token.txt
```

**Läuft der Server?** (Antwort sollte `active` sein)

```bash
systemctl is-active planer
```

**Server neu starten:**

```bash
sudo systemctl restart planer
```

**Auf eine neue Version aktualisieren:**

```bash
cd planer && git pull && sudo bash server/install.sh
```

Deine Aufgaben und dein Token bleiben dabei erhalten.

**Sicherungskopie machen** – alle Aufgaben stecken in **einer** Datei. So kopierst du sie in
deinen Benutzerordner auf dem Pi:

```bash
sudo cp /var/lib/planer/planer.db ~/planer-sicherung.db
```

Und so holst du sie auf deinen Computer (diesen Befehl auf dem **Computer** eingeben, nicht auf
dem Pi – also in einem neuen Fenster, ohne `ssh`):

```bash
scp ich@planer.local:planer-sicherung.db .
```

Mach das ab und zu, z. B. einmal im Monat.

---

## Probleme lösen

**`ssh: Could not resolve hostname planer.local`**
Der Pi ist noch nicht im Netzwerk. Warte ein paar Minuten. Prüfe, ob du im Imager das richtige
WLAN eingetragen hast. Du kannst auch in deinem Router (z. B. FRITZ!Box: `fritz.box` im Browser)
nachsehen, welche Adresse der Pi hat (z. B. `192.168.178.42`), und dann
`ssh ich@192.168.178.42` verwenden.

**`Permission denied` beim Anmelden**
Benutzername oder Passwort stimmen nicht. Achte auf Groß- und Kleinschreibung.

**App zeigt „Server nicht erreichbar“**
- Ist dein Gerät im selben WLAN wie der Pi (oder Tailscale eingeschaltet)?
- Steht `http://` bzw. `https://` vor der Adresse?
- Statt `planer.local` die Zahlen-Adresse versuchen, die das Installationsskript angezeigt hat
  (z. B. `http://192.168.178.42:8788`).
- Läuft der Server? → `systemctl is-active planer`

**App zeigt „Token ist falsch“**
Das Token genau so eintragen, wie es angezeigt wird (am besten kopieren). Anzeigen mit
`sudo cat /var/lib/planer/token.txt`.

**Ich habe dieselbe Aufgabe auf zwei Geräten geändert**
Dann gilt die zuletzt gespeicherte Änderung.

**Erinnerungen kommen nicht**
Auf dem iPhone: Einstellungen → Mitteilungen → Planer → Mitteilungen erlauben.

---

## Anhang: App selbst bauen

Nur nötig, wenn du die App nicht aus dem App Store installieren möchtest. Dafür brauchst du einen
**Mac**.

1. Installiere **Xcode** aus dem Mac App Store (kostenlos, sehr groß).
2. Lade dieses Projekt herunter: Auf der GitHub-Seite oben auf **„Code“ → „Download ZIP“** und
   entpacken – oder im Terminal: `git clone https://github.com/Minipliy/planer.git`
3. Öffne die Datei **`Planer.xcodeproj`** mit einem Doppelklick.
4. Klicke links auf das blaue **Planer**-Symbol, dann auf **Signing & Capabilities**:
   - Bei **Team** deine Apple-ID auswählen (über „Add Account…“ hinzufügen).
   - Bei **Bundle Identifier** etwas Eigenes eintragen, z. B. `de.deinname.planer`.
5. Verbinde dein iPhone per Kabel mit dem Mac, wähle es oben in Xcode als Ziel aus und klicke auf
   **▶ (Run)**.
6. Auf dem iPhone beim ersten Mal: Einstellungen → Allgemein → VPN & Geräteverwaltung → deinem
   Entwicklerprofil vertrauen. Eventuell musst du auch den **Entwicklermodus** einschalten
   (Einstellungen → Datenschutz & Sicherheit).

Mit einer kostenlosen Apple-ID läuft die selbst gebaute App 7 Tage und muss dann erneut aus Xcode
gestartet werden.

---

## Wörterbuch

- **Server:** ein Computer, der für andere Geräte etwas bereitstellt – hier: deine Aufgaben speichern.
- **Raspberry Pi:** kleiner, günstiger Computer, ideal als Server zu Hause.
- **Terminal / Befehlsfenster:** ein Fenster, in dem man einem Computer Befehle per Text gibt.
- **SSH:** eine sichere Verbindung, um einen anderen Computer per Befehlsfenster zu steuern.
- **sudo:** steht vor Befehlen, die Administratorrechte brauchen; fragt nach deinem Passwort.
- **Token:** ein langes, zufälliges Passwort, mit dem sich die App beim Server ausweist.
- **Port 8788:** eine Art „Türnummer“, unter der der Planer-Server erreichbar ist.
- **Tailscale:** Dienst, der deine Geräte verschlüsselt miteinander verbindet, egal wo sie sind.
