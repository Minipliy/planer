#!/usr/bin/env python3
"""Erzeugt die statischen Planer-Webseiten nach web/out (wird nach /srv/planer-site kopiert)."""
from pathlib import Path

OUT = Path(__file__).resolve().parent / "out"
STAND = "12. November 2026"
CONTACT = """<p>Lukas Hammer<br>Falkenstraße 12<br>01067 Dresden<br>Deutschland<br>
E-Mail: <a href="mailto:hyse@minipliy.net">hyse@minipliy.net</a></p>"""

CSS = """
:root{--bg:#f6f7fb;--fg:#16181d;--muted:#5c6170;--card:#fff;--line:#e3e5ec;--accent:#4772fa}
@media (prefers-color-scheme:dark){:root{--bg:#111318;--fg:#eef0f5;--muted:#a3a8b5;--card:#1b1e25;--line:#2b2f39;--accent:#7b9bff}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);
font:17px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
header,main,footer{max-width:760px;margin:0 auto;padding:0 20px}
header{display:flex;align-items:center;gap:12px;padding-top:28px;padding-bottom:8px}
header img{width:44px;height:44px;border-radius:10px}
header a.brand{font-weight:700;font-size:20px;color:var(--fg);text-decoration:none}
nav{margin-left:auto;display:flex;gap:16px}nav a{color:var(--muted);text-decoration:none}
nav a:hover{color:var(--accent)}a{color:var(--accent)}
h1{font-size:34px;line-height:1.2;margin:28px 0 8px}h2{font-size:21px;margin-top:32px}
.card{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:20px 24px;margin:18px 0}
.muted{color:var(--muted)}ul{padding-left:22px}
footer{border-top:1px solid var(--line);margin-top:48px;padding-top:18px;padding-bottom:40px;color:var(--muted);font-size:15px}
footer a{color:var(--muted);margin-right:14px}
"""


def page(path: str, title: str, body: str) -> None:
    html = f"""<!DOCTYPE html>
<html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} – Planer</title>
<meta name="description" content="Planer: Aufgaben und Kalender für iPhone, iPad und Mac, synchronisiert über deinen eigenen Server.">
<link rel="stylesheet" href="/assets/site.css"><link rel="icon" href="/assets/app-icon.png">
</head><body>
<header><img src="/assets/app-icon.png" alt=""><a class="brand" href="/">Planer</a>
<nav><a href="/einrichtung">Einrichtung</a><a href="https://github.com/Minipliy/planer">GitHub</a><a href="/support">Support</a></nav></header>
<main>{body}</main>
<footer><a href="https://github.com/Minipliy/planer">GitHub</a><a href="/support">Support</a><a href="/datenschutz">Datenschutz</a><a href="/impressum">Impressum</a>
<br>© 2026 Lukas Hammer · <a href="https://minipliy.net">minipliy</a></footer>
</body></html>
"""
    target = OUT / path / "index.html" if path else OUT / "index.html"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(html)


def main() -> None:
    (OUT / "assets").mkdir(parents=True, exist_ok=True)
    (OUT / "assets" / "site.css").write_text(CSS.strip() + "\n")

    page("", "Aufgaben & Kalender", """
<h1>Deine Aufgaben. Dein Kalender. Dein Server.</h1>
<p class="muted">Planer ist eine Aufgaben- und Kalender-App für iPhone, iPad und Mac. Deine Daten liegen
auf einem Server, den du selbst betreibst – zum Beispiel einem Raspberry Pi zu Hause – und werden
zwischen all deinen Geräten abgeglichen.</p>
<div class="card"><ul>
<li>Heute, Morgen, nächste 7 Tage, Eingang und eigene farbige Listen</li>
<li>Monatskalender mit allen Aufgaben pro Tag</li>
<li>Uhrzeiten, Erinnerungen, Wiederholungen, Prioritäten und Teilaufgaben</li>
<li>Funktioniert offline; Änderungen werden später übertragen</li>
<li>Kein Konto beim Entwickler, keine Werbung, kein Tracking</li>
</ul></div>
<div class="card"><p><strong>Offen und nachvollziehbar.</strong> Der komplette Quellcode von App und Server liegt öffentlich auf GitHub.
Das Projekt wurde mit Künstlicher Intelligenz (Claude) erstellt.</p>
<p><a href="https://github.com/Minipliy/planer/blob/main/docs/ANLEITUNG.md">Schritt-für-Schritt-Anleitung zum Einrichten →</a><br>
<a href="https://github.com/Minipliy/planer">Quellcode auf GitHub →</a></p></div>
""")

    page("einrichtung", "Einrichtung", """
<h1>Einrichtung</h1>
<p>Planer gleicht deine Daten mit einem eigenen Sync-Server ab – zum Beispiel einem Raspberry Pi bei dir
zu Hause. Der Server ist ein kleines Python-Programm ohne weitere Abhängigkeiten. Ohne Server funktioniert
die App ebenfalls; die Daten bleiben dann nur auf dem jeweiligen Gerät.</p>
<div class="card">
<p><strong>Ausführliche Anleitung – auch ohne Vorkenntnisse</strong></p>
<p>Von der leeren microSD-Karte bis zum Abgleich unterwegs, mit allen Befehlen zum Kopieren und Hilfe bei Problemen.</p>
<p><a href="https://github.com/Minipliy/planer/blob/main/docs/ANLEITUNG.md">Zur Schritt-für-Schritt-Anleitung auf GitHub →</a></p>
</div>
<h2>Kurzfassung</h2>
<div class="card"><ol>
<li>Auf dem Raspberry Pi (Raspberry Pi OS):<br>
<code>sudo apt install -y git python3</code><br>
<code>git clone https://github.com/Minipliy/planer.git</code><br>
<code>sudo bash planer/server/install.sh</code></li>
<li>Das Skript zeigt am Ende <strong>Serveradresse</strong> und <strong>Token</strong> an.</li>
<li>In der App auf das Zahnrad tippen und unter „Synchronisation“ Adresse und Token eintragen.</li>
<li>Auf jedem weiteren Gerät dasselbe eintragen.</li>
</ol></div>
<p>Für den Zugriff von unterwegs empfiehlt die Anleitung Tailscale – verschlüsselt und ohne Portfreigabe am
Router. Den Server bitte nie direkt per Portweiterleitung ins Internet stellen.</p>
<p>Quellcode von App und Server: <a href="https://github.com/Minipliy/planer">github.com/Minipliy/planer</a></p>
""")

    page("support", "Support", f"""
<h1>Support</h1>
<p>Fragen, Fehler oder Wünsche? Schreib eine E-Mail an
<a href="mailto:hyse@minipliy.net?subject=Planer">hyse@minipliy.net</a>. Nenne bitte dein Gerät,
die iOS- bzw. macOS-Version und was du getan hast, als das Problem auftrat.</p>
<h2>Häufige Fragen</h2>
<div class="card"><p><strong>Die App zeigt „Server nicht erreichbar“.</strong><br>Prüfe die Adresse
(mit <code>http://</code> oder <code>https://</code>) und ob der Server läuft. Deine Änderungen gehen nicht
verloren; sie werden übertragen, sobald der Server wieder erreichbar ist.</p>
<p><strong>„Token ist falsch“.</strong><br>Trage das Token exakt so ein, wie es der Server anzeigt.</p>
<p><strong>Was passiert, wenn ich dieselbe Aufgabe auf zwei Geräten ändere?</strong><br>Es gilt die
zuletzt gespeicherte Änderung.</p>
<p><strong>Wie lösche ich meine Daten?</strong><br>Lösche die App vom Gerät und die Datenbankdatei auf
deinem Server. Beim Entwickler werden keine Daten gespeichert.</p></div>
""")

    page("datenschutz", "Datenschutzerklärung", f"""
<h1>Datenschutzerklärung</h1>
<p class="muted">Stand: {STAND}</p>
<h2>1. Verantwortlicher</h2>{CONTACT}
<p>Diese Erklärung gilt für die App „Planer“ und die Website planer.minipliy.net.</p>
<h2>2. Daten in der App</h2>
<p>Die App speichert deine Aufgaben, Listen, Termine, Erinnerungen, die eingetragene Serveradresse und
das Token lokal auf deinem Gerät. Erinnerungen werden als lokale Mitteilungen vom Betriebssystem
geplant. Die App enthält keine Analyse-, Werbe- oder Tracking-Software und verlangt kein Konto beim
Entwickler.</p>
<h2>3. Synchronisation mit deinem Server</h2>
<p>Wenn du eine Serveradresse einträgst, überträgt die App deine Aufgaben und Listen an diesen Server und
lädt Änderungen von dort. Diesen Server wählst und betreibst du selbst; der Entwickler erhält dabei
keine Daten. Für die Verarbeitung auf deinem Server bist du selbst verantwortlich.</p>
<h2>4. Aufruf der Website</h2>
<p>Beim Aufruf dieser Website verarbeitet der Webserver technisch notwendige Verbindungsdaten (IP-Adresse,
Zeitpunkt, angeforderte Adresse, Browserinformationen), um die Seiten auszuliefern und den Betrieb zu
sichern (Art. 6 Abs. 1 lit. f DSGVO). Es wird kein dauerhaftes Zugriffsprotokoll geführt. Die Website
setzt keine Cookies und verwendet keine Analyse- oder Werbedienste. Hosting: STRATO GmbH,
Otto-Ostrowski-Straße 7, 10249 Berlin.</p>
<h2>5. Support-Anfragen</h2>
<p>Wenn du uns per E-Mail kontaktierst, verarbeiten wir deine Angaben nur zur Bearbeitung der Anfrage
(Art. 6 Abs. 1 lit. b bzw. f DSGVO) und löschen sie, wenn sie dafür nicht mehr benötigt werden.</p>
<h2>6. Deine Rechte</h2>
<p>Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung,
Datenübertragbarkeit und Widerspruch sowie das Recht auf Beschwerde bei einer Aufsichtsbehörde, etwa der
Sächsischen Datenschutz- und Transparenzbeauftragten.</p>
""")

    page("impressum", "Impressum", f"""
<h1>Impressum</h1>
<p class="muted">Stand: {STAND}</p>
<h2>Angaben gemäß § 5 DDG</h2>{CONTACT}
<h2>Streitbeilegung</h2>
<p>Der Anbieter ist nicht verpflichtet und nicht bereit, an Streitbeilegungsverfahren vor einer
Verbraucherschlichtungsstelle teilzunehmen.</p>
""")

    page("404", "Seite nicht gefunden", """<h1>Seite nicht gefunden</h1>
<p><a href="/">Zur Startseite</a></p>""")
    (OUT / "404" / "index.html").rename(OUT / "404.html")
    (OUT / "404").rmdir()
    (OUT / "robots.txt").write_text("User-agent: *\nAllow: /\n")


if __name__ == "__main__":
    main()
