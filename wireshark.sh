#!/usr/bin/env bash
set -euo pipefail

# Kontrola závislostí
for cmd in whiptail wireshark docker; do
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
container=$(whiptail --title "Wireshark Capture" \
  --menu "Vyber kontejner:" \
  20 30 10 "${menu_items[@]}" 3>&2 2>&1 1>&3) || exit 1

# Spuštění tcpdumpu v kontejneru
echo "📡 Spouštím tcpdump v kontejneru $container (rozhraní: any)..."

# Spuštění docker exec tcpdump v subshellu, který se ukončí, jakmile skončí wireshark
(
  # Spustí tcpdump a přesměruje do Wiresharku
  docker compose exec -T "$container" tcpdump -U -w - -i any 2>/dev/null | \
    wireshark -k -i - --capture-comment "Docker Compose container: $container (interface: any)"
) &

# Uloží PID subshellu
pid=$!

# Pohlídá, kdy Wireshark skončí – jakmile zavřeš okno, proces skončí a pipe se přeruší
wait $pid 2>/dev/null || true

# Kill fallback (pokud docker exec stále běží)
pgrep -f "docker compose exec -T $container tcpdump" >/dev/null && \
  pkill -f "docker compose exec -T $container tcpdump" 2>/dev/null || true
