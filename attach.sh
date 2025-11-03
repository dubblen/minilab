#!/bin/bash

#!/usr/bin/env bash
set -euo pipefail

# Kontrola závislostí
for cmd in whiptail docker; do
  command -v "$cmd" >/dev/null || { echo "❌ $cmd není nainstalován."; exit 1; }
done

# Ověření docker-compose.yml
if [ ! -f docker-compose.yaml ] && [ ! -f docker-compose.yml ]; then
  whiptail --msgbox "❌ V aktuálním adresáři nebyl nalezen docker-compose.yaml." 8 60
  exit 1
fi

# Získání běžících kontejnerů z Compose projektu
containers=$(docker compose ps --format '{{.Name}}' 2>/dev/null | grep -v '^$' || true)
if [ -z "$containers" ]; then
  whiptail --msgbox "❌ Žádné běžící kontejnery z docker-compose projektu nebyly nalezeny." 8 70
  exit 0
fi

# Připravení menu
menu_items=()
for c in $containers; do
  menu_items+=("$c" "")
done

# Výběr kontejneru
container=$(whiptail --title "Docker Attach" \
  --menu "Vyber kontejner:" \
  20 30 10 "${menu_items[@]}" 3>&2 2>&1 1>&3) || exit 1

docker-compose exec -itw /root "$container" bash
