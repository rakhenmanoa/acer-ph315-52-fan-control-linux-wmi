#!/bin/sh
# Désinstalle le module (le pilote acer-wmi d'origine du noyau reprend la main).
#
# Usage : sudo ./uninstall.sh [--tools]
#   --tools  supprime aussi les scripts d'effets et leurs services
set -e

NAME=acer-ph315-52-fan-control-linux-wmi
[ "$(id -u)" -eq 0 ] || { echo "Erreur : lancer avec sudo" >&2; exit 1; }

for v in $(dkms status -m "$NAME" 2>/dev/null | sed -n "s#^${NAME}[/,] *\([^,:]*\).*#\1#p" | sort -u); do
	echo "==> Suppression de $NAME/$v"
	dkms remove "$NAME/$v" --all >/dev/null || true
	rm -rf "/usr/src/$NAME-$v"
done

if [ "$1" = "--tools" ]; then
	for s in acer-kbd-effect acer-kbd-rainbow acer-kbd-temp acer-kbd-heartbeat; do
		systemctl disable --now "$s.service" 2>/dev/null || true
		rm -f "/etc/systemd/system/$s.service" "/usr/local/bin/$s"
	done
	rm -f /etc/udev/rules.d/99-acer-kbd-effect.rules
	systemctl daemon-reload
fi

if modprobe -r acer_wmi 2>/dev/null; then
	modprobe acer_wmi || true
	echo "==> Pilote d'origine rechargé : $(modinfo -n acer_wmi 2>/dev/null)"
else
	echo "==> Module en cours d'utilisation : redémarrez pour revenir au pilote d'origine."
fi
