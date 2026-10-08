# Acer PH315-52 fan control (Linux WMI)

Version modifiée du pilote noyau `acer-wmi` pour l'Acer Predator Helios 300 (PH315-52).

Ajouts par rapport au pilote d'origine :

- `/dev/acer-gkbbl-0` : effets de rétroéclairage du clavier (tampon de 16 octets)
- `/dev/acer-gkbbl-static-0` : couleur statique du clavier (tampon de 4 octets)
- Activation des 4 zones du clavier au chargement, et fichiers accessibles sans `sudo`

Les noms des périphériques sont les mêmes que dans le module de Jafar Akhondali :
ses outils `facer_rgb.py` et `keyboard.py` fonctionnent tels quels.

- LED `acer::kbd_backlight` : luminosité du clavier réglable depuis le curseur de KDE ou GNOME (via UPower)
- LED `acer:rgb:kbd_zone-1` à `-4` : couleur de chaque zone via l'interface LED multicolore standard
- Restauration de l'effet et des couleurs après une mise en veille
- Quirks PH315-52 : mode turbo, ventilateurs CPU/GPU, capteurs hwmon et contrôle PWM

Le profil énergétique (*platform profile*) Predator v4 est désactivé sur le PH315-52 :
il entre en conflit avec la gestion d'énergie de KDE, qui fonctionne mieux sans lui.
Pour le réactiver à titre de test : `options acer_wmi enable_platform_profile=1`
dans `/etc/modprobe.d/acer-wmi.conf`.

## Prérequis

Les outils de compilation et les en-têtes du noyau en cours d'exécution.

Manjaro / Arch :

```sh
uname -r                                  # ex. 7.1.13-2-MANJARO
sudo pacman -S base-devel linux71-headers  # adapter "linux71" à votre noyau
```

Debian / Ubuntu :

```sh
sudo apt install build-essential linux-headers-$(uname -r)
```

Récupérer les sources :

```sh
git clone https://github.com/rakhenmanoa/acer-ph315-52-fan-control-linux-wmi
cd acer-ph315-52-fan-control-linux-wmi
```

## Option 1 : compilation manuelle

Utile pour tester rapidement une modification. Le module devra être recompilé à chaque mise à jour du noyau.

### Compiler

```sh
make
```

Cela produit `acer-wmi.ko` dans le dossier courant.

### Tester sans installer

Le pilote d'origine est généralement déjà chargé : il faut le retirer d'abord. `insmod` ne charge pas les dépendances, d'où les `modprobe` préalables.

```sh
sudo modprobe -r acer_wmi
sudo modprobe -a wmi sparse-keymap platform_profile
sudo insmod ./acer-wmi.ko
sudo dmesg | tail -20
```

Pour revenir au pilote d'origine :

```sh
sudo rmmod acer_wmi
sudo modprobe acer_wmi
```

### Installer de façon permanente

Le dossier `updates/` est prioritaire sur le pilote fourni avec le noyau :

```sh
sudo mkdir -p /lib/modules/$(uname -r)/updates
sudo cp acer-wmi.ko /lib/modules/$(uname -r)/updates/
sudo depmod -a
sudo modprobe -r acer_wmi && sudo modprobe acer_wmi
```

Le module se charge ensuite automatiquement au démarrage, tant que le noyau ne change pas.

### Nettoyer

```sh
make clean
```

## Option 2 : installation via DKMS (recommandée)

DKMS recompile et réinstalle le module automatiquement à chaque mise à jour du noyau.

### Installer DKMS

```sh
sudo pacman -S dkms          # Manjaro / Arch
sudo apt install dkms        # Debian / Ubuntu
```

### Installer le module

Depuis le dossier du dépôt :

```sh
sudo mkdir -p /usr/src/acer-ph315-52-fan-control-linux-wmi-1.0
sudo cp acer-wmi.c Makefile dkms.conf /usr/src/acer-ph315-52-fan-control-linux-wmi-1.0/
sudo dkms install acer-ph315-52-fan-control-linux-wmi/1.0
sudo modprobe -r acer_wmi && sudo modprobe acer_wmi
```

### Mettre à jour après une modification du source

```sh
sudo dkms remove acer-ph315-52-fan-control-linux-wmi/1.0 --all
sudo cp acer-wmi.c Makefile dkms.conf /usr/src/acer-ph315-52-fan-control-linux-wmi-1.0/
sudo dkms install acer-ph315-52-fan-control-linux-wmi/1.0
sudo modprobe -r acer_wmi && sudo modprobe acer_wmi
```

### Désinstaller

```sh
sudo dkms remove acer-ph315-52-fan-control-linux-wmi/1.0 --all
sudo rm -rf /usr/src/acer-ph315-52-fan-control-linux-wmi-1.0
sudo modprobe -r acer_wmi && sudo modprobe acer_wmi   # recharge le pilote d'origine
```

## Vérifier l'installation

```sh
modinfo -n acer_wmi          # doit pointer vers .../updates/...
dkms status                  # si installé via DKMS
ls /dev/acer-gkbbl*
sensors | grep -A5 acer      # températures et vitesses des ventilateurs
```

Si `modinfo` pointe vers `kernel/drivers/platform/x86/`, c'est encore le pilote d'origine qui est utilisé. Lancez `sudo depmod -a` puis rechargez le module.

Si le module figure dans l'initramfs, régénérez-le : `sudo mkinitcpio -P` (Arch) ou `sudo update-initramfs -u` (Debian).

## Effets du clavier

Le script `tools/acer-kbd-effect` écrit directement dans le périphérique, sans Python :

```sh
tools/acer-kbd-effect 3 5 100                                   # vague
tools/acer-kbd-effect 1 4 100 1 255 0 255                       # respiration violette
tools/acer-kbd-effect static 80 1:255:0:0 2:0:255:0 3:0:0:255 4:255:255:255
```

Modes : 1 respiration, 2 néon, 3 vague, 4 décalage, 5 zoom.
Arguments : `MODE VITESSE(0-9) LUMINOSITE(0-100) DIRECTION(1-2) R V B`.

Les outils `facer_rgb.py` et `keyboard.py` de Jafar Akhondali fonctionnent aussi.

### Effet au démarrage

```sh
sudo install -m 755 tools/acer-kbd-effect /usr/local/bin/
sudo install -m 644 tools/acer-kbd-effect.conf /etc/
sudo install -m 644 tools/acer-kbd-effect.service /etc/systemd/system/
sudo install -m 644 tools/99-acer-kbd-effect.rules /etc/udev/rules.d/
sudo systemctl daemon-reload && sudo udevadm control --reload
```

Choisissez l'effet dans `/etc/acer-kbd-effect.conf` (variable `EFFECT`). Il est appliqué
à chaque chargement du module, donc au démarrage. Pour l'appliquer tout de suite :
`sudo systemctl start acer-kbd-effect`.

## Luminosité du clavier depuis le bureau

Le module crée la LED standard `/sys/class/leds/acer::kbd_backlight` (0 à 100).
UPower la détecte, et le curseur de luminosité clavier de KDE ou GNOME l'utilise.
Seule la luminosité change : le mode, la vitesse et les couleurs restent ceux
du dernier réglage envoyé via `/dev/acer-gkbbl-0`.

Test manuel :

```sh
echo 30 | sudo tee /sys/class/leds/acer::kbd_backlight/brightness
```

Après le chargement du module, redémarrez UPower pour que KDE voie la LED :
`sudo systemctl restart upower`.

## Couleur par zone (LED multicolores)

Chaque zone du clavier (1 à 4, de gauche à droite) est une LED multicolore standard :

```sh
Z=/sys/class/leds/acer:rgb:kbd_zone-1
echo 255 0 128 | sudo tee $Z/multi_intensity   # couleur R V B
echo 255       | sudo tee $Z/brightness        # applique (0-255)
```

Régler une zone passe le clavier en mode statique. La luminosité générale
reste celle de `acer::kbd_backlight`.

Ces LED nécessitent `CONFIG_LEDS_CLASS_MULTICOLOR` (activé dans les noyaux Manjaro et Arch).

## Contrôle des ventilateurs

Via hwmon, dans le dossier `/sys/class/hwmon/hwmonX/` dont le fichier `name` contient `acer` :

| Fichier | Rôle |
|---|---|
| `pwm1_enable`, `pwm2_enable` | 0 = turbo, 1 = manuel, 2 = auto (CPU, GPU) |
| `pwm1`, `pwm2` | vitesse 0–255 en mode manuel |
| `fan1_input`, `fan2_input` | vitesse mesurée (tr/min) |
| `temp1_input` … `temp3_input` | CPU, GPU, capteur externe (millidegrés) |

Exemple, ventilateur CPU à 50 % :

```sh
H=$(grep -l acer /sys/class/hwmon/hwmon*/name | xargs dirname)
echo 1   | sudo tee $H/pwm1_enable
echo 128 | sudo tee $H/pwm1
```

Retour en automatique :

```sh
echo 2 | sudo tee $H/pwm1_enable
```

## Ancien service systemd

Si vous chargiez le module avec un service `insmod` et un chemin en dur, désactivez-le : il échouera à la prochaine mise à jour du noyau.

```sh
sudo systemctl disable --now acer_wmi.service
sudo rm /etc/systemd/system/acer_wmi.service
sudo systemctl daemon-reload
```

## Crédits

Ce module s'inspire du travail de **Jafar Akhondali** et de son projet
[acer-predator-turbo-and-rgb-keyboard-linux-module](https://github.com/JafarAkhondali/acer-predator-turbo-and-rgb-keyboard-linux-module),
qui a introduit les interfaces `/dev/acer-gkbbl` et `/dev/acer-gkbbl-static`
pour le rétroéclairage RGB et le mode turbo des portables Acer Predator, Helios et Nitro.

Il repose sur le pilote `acer-wmi` du noyau Linux, écrit par Carlos Corbacho
et maintenu par la communauté.

## Licence

GPL-2.0-or-later, comme le pilote `acer-wmi` d'origine (Carlos Corbacho et contributeurs).
