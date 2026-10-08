#!/bin/sh
# Installe (ou met à jour) le module via DKMS en une commande.
#
# Usage : sudo ./install.sh [--tools]
#   --tools  installe aussi les scripts d'effets clavier dans /usr/local/bin
#            et leurs services systemd (sans les activer)
set -e
cd "$(dirname "$0")"

NAME=acer-ph315-52-fan-control-linux-wmi
VER=$(cat VERSION)
# Anciens noms sous lesquels le module a pu être installé
OLD_NAMES="acer-wmi-gkbbl acer-ph315-52-fan-control-wmi acer-wmi"
WITH_TOOLS=0
[ "$1" = "--tools" ] && WITH_TOOLS=1

say() { printf '\033[1m==> %s\033[0m\n' "$*"; }
die() { printf 'Erreur : %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "lancer avec sudo"
command -v dkms >/dev/null || die "dkms absent (sudo pacman -S dkms)"

KREL=$(uname -r)
if [ ! -d "/lib/modules/$KREL/build" ]; then
	maj=$(echo "$KREL" | cut -d. -f1); min=$(echo "$KREL" | cut -d. -f2)
	die "en-têtes du noyau $KREL absents (Manjaro : sudo pacman -S linux$maj$min-headers)"
fi

# Versions installées d'un paquet DKMS (formats dkms 2 et 3)
dkms_versions() {
	dkms status -m "$1" 2>/dev/null |
		sed -n "s#^$1[/,] *\([^,:]*\).*#\1#p" | sort -u
}

say "Suppression des installations précédentes"
for n in $OLD_NAMES $NAME; do
	for v in $(dkms_versions "$n"); do
		echo "   $n/$v"
		dkms remove "$n/$v" --all >/dev/null || true
		rm -rf "/usr/src/$n-$v"
	done
done

say "Copie des sources (version $VER)"
SRC=/usr/src/$NAME-$VER
mkdir -p "$SRC"
cp acer-wmi.c Makefile VERSION "$SRC/"
sed "s/^PACKAGE_VERSION=.*/PACKAGE_VERSION=\"$VER\"/" dkms.conf > "$SRC/dkms.conf"

say "Compilation et installation DKMS"
dkms install "$NAME/$VER"

say "Rechargement du module"
if modprobe -r acer_wmi 2>/dev/null; then
	modprobe acer_wmi
	systemctl try-restart upower 2>/dev/null || true
else
	echo "   Module en cours d'utilisation : redémarrez pour charger la nouvelle version."
fi

if [ "$WITH_TOOLS" -eq 1 ]; then
	say "Installation des outils"
	for f in tools/acer-kbd-effect tools/acer-kbd-rainbow tools/acer-kbd-temp tools/acer-kbd-heartbeat; do
		install -m 755 "$f" /usr/local/bin/
	done
	install -m 644 tools/*.service /etc/systemd/system/
	[ -e /etc/acer-kbd-effect.conf ] || install -m 644 tools/acer-kbd-effect.conf /etc/
	systemctl daemon-reload
fi

if [ -e /etc/systemd/system/acer_wmi.service ]; then
	echo
	echo "Attention : l'ancien service acer_wmi.service (insmod) est toujours présent."
	echo "Il n'est plus nécessaire :"
	echo "   sudo systemctl disable --now acer_wmi.service && sudo rm /etc/systemd/system/acer_wmi.service"
fi

echo
say "Terminé"
echo "   Fichier chargé : $(modinfo -n acer_wmi 2>/dev/null)"
echo "   Version        : $(modinfo -F version acer_wmi 2>/dev/null)"
