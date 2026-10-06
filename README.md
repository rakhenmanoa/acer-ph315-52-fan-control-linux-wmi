# Acer PH315-52 fan control (Linux WMI)

Version modifiée du pilote noyau `acer-wmi` pour l'Acer Predator Helios 300 (PH315-52).

Ajouts par rapport au pilote d'origine :

- `/dev/acer-gkbbl` : effets de rétroéclairage du clavier (tampon de 16 octets)
- `/dev/acer-gkbbl-static` : couleur statique du clavier (tampon de 4 octets)
- Quirks PH315-52 : mode turbo, ventilateurs CPU/GPU, capteurs hwmon et contrôle PWM

L'enregistrement du *platform profile* est désactivé dans cette version.

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

## Licence

GPL-2.0-or-later, comme le pilote `acer-wmi` d'origine (Carlos Corbacho et contributeurs).
