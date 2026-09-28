#!/usr/bin/env bash
#
# Script d'installation d'outils de pentest sur la plupart des distros Linux.
# À exécuter avec sudo : sudo ./install.sh
#
# Outils : openvpn, nmap, hydra, gobuster, netcat, SecLists

# --- 1. Vérifier qu'on est root ---------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être lancé avec sudo." >&2
    exit 1
fi

# --- 2. Détecter la distro --------------------------------------------------
. /etc/os-release

# On regarde d'abord $ID, puis $ID_LIKE pour gérer les dérivées
# (Mint, Pop!_OS, CachyOS, Manjaro, Rocky, Alma...).
FAMILLE="inconnu"
for id in $ID ${ID_LIKE:-}; do
    case "$id" in
        debian|ubuntu|kali)
            FAMILLE="debian"
            break
            ;;
        fedora|rhel|centos)
            FAMILLE="fedora"
            break
            ;;
        arch)
            FAMILLE="arch"
            break
            ;;
    esac
done

echo "Distro détectée : $ID (famille : $FAMILLE)"

# --- 3. Listes de paquets par famille ---------------------------------------
# Les noms varient d'une distro à l'autre (surtout netcat).
PAQUETS_DEBIAN=(git openvpn nmap hydra gobuster netcat-openbsd)
PAQUETS_FEDORA=(git openvpn nmap hydra gobuster nmap-ncat)
PAQUETS_ARCH=(git openvpn nmap hydra gobuster openbsd-netcat)

# --- 4. Commande d'installation et liste selon la famille -------------------
case "$FAMILLE" in
    debian)
        apt-get update
        INSTALL_CMD=(apt-get install -y)
        PAQUETS=("${PAQUETS_DEBIAN[@]}")
        ;;
    fedora)
        INSTALL_CMD=(dnf install -y)
        PAQUETS=("${PAQUETS_FEDORA[@]}")
        ;;
    arch)
        pacman -Sy
        INSTALL_CMD=(pacman -S --noconfirm --needed)
        PAQUETS=("${PAQUETS_ARCH[@]}")
        ;;
    *)
        echo "Distro non supportée : $ID" >&2
        exit 1
        ;;
esac

# --- 5. Installation paquet par paquet --------------------------------------
# Un par un pour qu'un paquet introuvable n'arrête pas tout le script.
ECHECS=()

installer() {
    local paquet="$1"
    echo ">>> Installation de $paquet"
    if ! "${INSTALL_CMD[@]}" "$paquet"; then
        echo "!!! Échec : $paquet"
        ECHECS+=("$paquet")
    fi
}

for paquet in "${PAQUETS[@]}"; do
    installer "$paquet"
done

# --- 6. SecLists (git clone, méthode commune à toutes les distros) ----------
DEST="/usr/share/seclists"

if [ -d "$DEST" ]; then
    echo ">>> SecLists déjà présent dans $DEST, on passe."
else
    echo ">>> Clonage de SecLists dans $DEST"
    if ! git clone --depth 1 https://github.com/danielmiessler/SecLists.git "$DEST"; then
        echo "!!! Échec : SecLists"
        ECHECS+=("seclists")
    fi
fi

# --- 7. Résumé --------------------------------------------------------------
echo
if [ "${#ECHECS[@]}" -eq 0 ]; then
    echo "Tout a été installé avec succès."
else
    echo "Éléments non installés : ${ECHECS[*]}"
    echo "Vérifie leur nom de paquet ou installe-les manuellement."
    exit 1
fi
