#!/bin/bash
# Richtet den Planer Sync-Server als eigenen Systemdienst mit eigenem Benutzer "planer" ein.
#   Programm: /opt/planer/server.py      Daten: /var/lib/planer      Dienst: planer.service
# Aufruf:  sudo bash install.sh
set -e
if [ "$(id -u)" != 0 ]; then echo "Bitte mit sudo starten:  sudo bash $0"; exit 1; fi
DIR="$(cd "$(dirname "$0")" && pwd)"
command -v python3 >/dev/null || { echo "Python 3 fehlt. Erst ausführen: sudo apt install -y python3"; exit 1; }

# Früheren Benutzerdienst (falls vorhanden) abschalten.
if [ -n "$SUDO_USER" ]; then
    OLD_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    if [ -f "$OLD_HOME/.config/systemd/user/planer.service" ]; then
        sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$SUDO_USER")" \
            systemctl --user disable --now planer || true
        rm -f "$OLD_HOME/.config/systemd/user/planer.service"
        sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$SUDO_USER")" \
            systemctl --user daemon-reload || true
    fi
fi

# Eigener Benutzer ohne Login.
id planer >/dev/null 2>&1 || useradd --system --home-dir /var/lib/planer --shell /usr/sbin/nologin planer

install -d -o root -g root -m 755 /opt/planer
install -o root -g root -m 644 "$DIR/server.py" /opt/planer/server.py
install -d -o planer -g planer -m 700 /var/lib/planer

# Vorhandene Daten (Datenbank und Token) übernehmen, damit der Token gleich bleibt.
if [ -d "$DIR/data" ] && [ ! -e /var/lib/planer/token.txt ]; then
    cp -a "$DIR/data/." /var/lib/planer/
fi
chown -R planer:planer /var/lib/planer

cat > /etc/systemd/system/planer.service <<EOF
[Unit]
Description=Planer Sync-Server
After=network-online.target
Wants=network-online.target

[Service]
User=planer
Group=planer
Environment=PLANER_DATA=/var/lib/planer
ExecStart=/usr/bin/python3 /opt/planer/server.py
Restart=always
RestartSec=3
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
ReadWritePaths=/var/lib/planer

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable planer
systemctl restart planer
sleep 2
systemctl is-active planer

echo
echo "=============================================================="
echo " Fertig! Der Planer-Server läuft."
echo
echo " Trage in der App unter Einstellungen > Synchronisation ein:"
echo "   Serveradresse:  http://$(hostname).local:8788"
echo "   (falls das nicht klappt: http://$(hostname -I | awk '{print $1}'):8788)"
echo "   Token:          $(cat /var/lib/planer/token.txt)"
echo
echo " Token später noch einmal anzeigen:"
echo "   sudo cat /var/lib/planer/token.txt"
echo "=============================================================="
