#!/usr/bin/env python3
"""Füllt einen (Demo-)Server mit Beispieldaten.  Aufruf: python3 seed_demo.py URL TOKEN"""
import json
import sys
import time
import urllib.request
import uuid
from datetime import datetime, timedelta

url, token = sys.argv[1].rstrip("/"), sys.argv[2]
now = int(time.time() * 1000)
today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
# Termine für heute in den nächsten Stunden, damit nichts überfällig erscheint.
h = min(datetime.now().hour + 1, 20)


def ms(d: datetime) -> int:
    return int(d.timestamp() * 1000)


def lst(name, color):
    return {"id": str(uuid.uuid4()).upper(), "name": name, "colorHex": color, "createdAt": now,
            "updatedAt": now, "deleted": False, "dirty": False}


work, private, shop = lst("Arbeit", "4772FA"), lst("Privat", "30A46C"), lst("Einkauf", "F5A623")


def task(title, days=None, hour=None, lst=None, prio=0, notes="", subs=(), repeat="none", reminder=None, done=False):
    due = None
    if days is not None:
        d = today + timedelta(days=days)
        if hour is not None:
            d = d.replace(hour=hour[0], minute=hour[1])
        due = ms(d)
    return {"id": str(uuid.uuid4()).upper(), "title": title, "notes": notes,
            "listID": lst["id"] if lst else None, "dueDate": due, "hasTime": hour is not None,
            "reminderMinutes": reminder, "repeatRule": repeat, "priority": prio,
            "isCompleted": done, "completedAt": now if done else None,
            "subtasks": [{"id": str(uuid.uuid4()).upper(), "title": s, "done": i == 0} for i, s in enumerate(subs)],
            "createdAt": now, "updatedAt": now, "deleted": False, "dirty": False}


tasks = [
    task("Präsentation fertigstellen", 0, (h, 0), work, 3, "Folien 5–12 überarbeiten", ("Zahlen prüfen", "Grafiken"), reminder=15),
    task("Team-Meeting", 0, (h + 1, 30), work, 2, repeat="weekly", reminder=10),
    task("Obst und Gemüse", 0, None, shop, 0, subs=("Äpfel", "Tomaten", "Bananen")),
    task("Laufen gehen", 0, (h + 3, 0), private, 1, repeat="weekdays"),
    task("Rechnung bezahlen", 1, None, private, 3, reminder=0),
    task("Zahnarzt anrufen", 1, (9, 0), private, 2),
    task("Angebot an Kunden schicken", 2, None, work, 2),
    task("Geburtstagsgeschenk für Anna", 4, None, private, 1),
    task("Wochenrückblick", 5, (17, 0), work, 0, repeat="weekly"),
    task("Fahrrad zur Inspektion", 9, None, private, 0),
    task("Ideen für Urlaub sammeln", None, None, None, 0, "Berge oder Meer?"),
    task("Wasser kaufen", 0, None, shop, 0, done=True),
]
records = [{"id": x["id"], "kind": "list", "updatedAt": now, "deleted": False, "data": json.dumps(x)}
           for x in (work, private, shop)]
records += [{"id": x["id"], "kind": "task", "updatedAt": now, "deleted": False, "data": json.dumps(x)}
            for x in tasks]
req = urllib.request.Request(url + "/sync", data=json.dumps({"since": 0, "changes": records}).encode(),
                             headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"})
print(urllib.request.urlopen(req, timeout=10).read().decode()[:80])
