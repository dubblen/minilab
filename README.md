# Cvičení

**Dependencies:**
- docker (with docker compose)
- wireshark
- whiptail

**Deploy:**
```bash
docker compose up -d
```

- `attach.sh` - připojení na shell zvoleného zařízení
- `wireshark.sh` - spuštění wiresharku a sledování síťového provozu zařízení


## 1. Topologie

```
         network_a (10.10.0.0/24)               network_b (10.20.0.0/24)
   ┌──────────────────────────────┐         ┌──────────────────────────────┐
   │   client (10.10.0.3)         │         │   server (10.20.0.3)         │
   │     ↕ via 10.10.0.2          │         │     ↕ via 10.20.0.2          │
   └────────────┬─────────────────┘         └────────────┬─────────────────┘
                │                                        │
                └──── router (10.10.0.2 / 10.20.0.2) ────┘
```

Router propojuje obě sítě a má zapnuté přeposílání paketů (`ip_forward=1`).

---

## 2. Spuštění prostředí

```bash
docker compose up -d
docker ps
```

### Ověření základní konektivity

**Z kontejneru client:**
```bash
ping -c2 10.10.0.2
```
**Očekávaný výstup:**
```
PING 10.10.0.2 (10.10.0.2): 56 data bytes
64 bytes from 10.10.0.2: icmp_seq=1 ttl=64 time=0.1 ms
64 bytes from 10.10.0.2: icmp_seq=2 ttl=64 time=0.1 ms
```

**Z kontejneru router:**
```bash
ping -c2 10.20.0.3
```
**Očekávaný výstup:**
```
64 bytes from 10.20.0.3: icmp_seq=1 ttl=64 time=0.1 ms
64 bytes from 10.20.0.3: icmp_seq=2 ttl=64 time=0.1 ms
```

---

## 3. Tabulka FILTER – filtrování paketů

### 🧩 Úkol 3.1 – Zablokování ICMP z jedné sítě do druhé

**Na routeru:**
```bash
iptables -A FORWARD -p icmp -s 10.10.0.0/24 -d 10.20.0.0/24 -j DROP
```

**Z clienta:**
```bash
ping -c2 10.20.0.3
```
**Očekávaný výstup:**
```
From 10.10.0.2 icmp_seq=1 Destination Host Prohibited
From 10.10.0.2 icmp_seq=2 Destination Host Prohibited
```

*Ping neprojde.*

**Z serveru** však ping na klienta projde:
```bash
ping -c2 10.10.0.3
```

**Očekávaný výstup:**
```
64 bytes from 10.10.0.3: icmp_seq=1 ttl=63 time=0.2 ms
64 bytes from 10.10.0.3: icmp_seq=2 ttl=63 time=0.2 ms
```

---

### 🧩 Úkol 3.2 – Povolit ICMP jen v jednom směru

**Na routeru:**
```bash
iptables -A FORWARD -p icmp -s 10.20.0.0/24 -d 10.10.0.0/24 -j ACCEPT
```

> Ping **ze serveru na klienta** projde, ale **z klienta na server** ne.

---

### Úkol 3.3 – Filtrování TCP portů

Otevření 2 portů na **serveru:**
```bash
nc -l -p 80
nc -l -p 22
```

**Na routeru:**
```bash
iptables -A FORWARD -p tcp --dport 80 -s 10.10.0.0/24 -d 10.20.0.0/24 -j DROP
iptables -A FORWARD -p tcp --dport 22 -s 10.10.0.0/24 -d 10.20.0.0/24 -j ACCEPT
```

**Na clientu:**
```bash
nc -zv 10.20.0.3 22
nc -zv 10.20.0.3 80
```

> Na portu 22 by se měla navázat komunikace přes netcat.
> Naopak na portu 80 by se navázat neměla.

---

### Úkol 3.4 – Stavové filtrování

**Na routeru:**
```bash
iptables -P FORWARD DROP
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p icmp -s 10.10.0.0/24 -d 10.20.0.0/24 -j ACCEPT
```

**Z clienta:**
```bash
ping -c2 10.20.0.3
```

**Očekávaný výstup:**
```
64 bytes from 10.20.0.3: icmp_seq=1 ttl=63 time=0.2 ms
64 bytes from 10.20.0.3: icmp_seq=2 ttl=63 time=0.2 ms
```

> Stavový firewall umožnil odpověď díky `ESTABLISHED`.

---

### Úkol 3.5 – Logování zahazovaných paketů

**Na routeru:**
```bash
iptables -A FORWARD -j LOG --log-prefix 'FWD DROP: '
```

**Z clienta:**
```bash
nc -zv 10.20.0.3 9999
```

**Na routeru:**
```bash
dmesg | tail
```

**Očekávaný výstup:**
```
[12345.678901] FWD DROP: IN=eth0 OUT=eth1 SRC=10.10.0.3 DST=10.20.0.3 LEN=60 ...
```

---

## 4. Tabulka NAT – přepisování adres

### 🧩 Úkol 4.1 – Masquerade

**Na routeru:**
```bash
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
```

**Z clienta:**
```bash
ping -c2 10.20.0.3
```

**Na serveru:**
```bash
tcpdump -n -i eth0 icmp
```

**Očekávaný výstup:**
```
10.20.0.2 > 10.20.0.3: ICMP echo request, id 44, seq 1
10.20.0.3 > 10.20.0.2: ICMP echo reply, id 44, seq 1
```

> Zdrojová IP = `10.20.0.2` (router).

---

### Úkol 4.2 – DNAT (port forward)

**Na routeru:**
```bash
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.20.0.3:80
```

**Z clienta:**
```bash
nc -zv 10.10.0.2 8080
```

**Očekávaný výstup:**
```
Connection to 10.10.0.2 8080 port [tcp/http-alt] succeeded!
```

> Router přesměroval spojení na `server:80`.

---

### Úkol 4.3 – SNAT (změna zdrojové IP)

**Na routeru:**
```bash
iptables -t nat -A POSTROUTING -s 10.10.0.0/24 -o eth1 -j SNAT --to-source 10.20.0.2
```

**Z clienta:**
```bash
nc -zv 10.20.0.3 22
```

**Na serveru:**
```bash
tcpdump -n -i eth0 tcp
```

**Očekávaný výstup:**
```
10.20.0.2.45322 > 10.20.0.3.22: Flags [S], seq 123456789, win 64240
```

> Zdrojová IP je `10.20.0.2`.

---

### Úkol 4.4 – Kombinace DNAT + SNAT

**Na routeru:**
```bash
iptables -t nat -A PREROUTING -p tcp --dport 9090 -j DNAT --to-destination 10.20.0.3:22
iptables -t nat -A POSTROUTING -p tcp -d 10.20.0.3 --dport 22 -j SNAT --to-source 10.20.0.2
```

**Z clienta:**
```bash
nc -zv 10.10.0.2 9090
```

**Očekávaný výstup:**
```
Connection to 10.10.0.2 9090 port [tcp/*] succeeded!
```

> Router přesměruje port 9090 → server:22 a maskuje zdroj.


---

### Úkol 3.6 – Povolení komunikace pouze pro konkrétní IP

**Na routeru:**
```bash
iptables -A FORWARD -s 10.10.0.3 -d 10.20.0.3 -p icmp -j ACCEPT
iptables -A FORWARD -s 10.10.0.0/24 ! -s 10.10.0.3 -d 10.20.0.0/24 -j DROP
```

**Z clienta:**
```bash
ping -c2 10.20.0.3
```

**Očekávaný výstup:**
```
64 bytes from 10.20.0.3: icmp_seq=1 ttl=63 time=0.2 ms
64 bytes from 10.20.0.3: icmp_seq=2 ttl=63 time=0.2 ms
```

> Firewall povolí ICMP pouze pro konkrétní IP adresu.

---

### Úkol 3.7 – Filtrování podle rozhraní

**Na routeru:**
```bash
iptables -A FORWARD -i eth0 -o eth1 -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -i eth1 -o eth0 -p tcp --dport 22 -j DROP
```

**Z clienta:**
```bash
nc -zv 10.20.0.3 22
```

**Očekávaný výstup:**
```
Connection to 10.20.0.3 22 port [tcp/ssh] succeeded!
```

**Z serveru (opačným směrem):**
```bash
nc -zv 10.10.0.3 22
```

**Očekávaný výstup:**
```
nc: connect to 10.10.0.3 port 22 (tcp) failed: Connection refused
```

> Přístup je povolen pouze jedním směrem podle rozhraní.

---

### Úkol 3.8 – Rate limit ICMP provozu

**Na routeru:**
```bash
iptables -A FORWARD -p icmp -m limit --limit 1/second -j ACCEPT
iptables -A FORWARD -p icmp -j DROP
```

**Z clienta:**
```bash
ping -i 0.2 10.20.0.3
```

**Očekávaný výstup:**
```
ping: sendmsg: Operation not permitted
ping: sendmsg: Operation not permitted
64 bytes from 10.20.0.3: icmp_seq=5 ttl=63 time=0.2 ms
```

> Router propustí maximálně 1 ICMP paket za sekundu.

---

### Úkol 4.5 – Přesměrování portu na jiný port (port translation)

**Na routeru:**
```bash
iptables -t nat -A PREROUTING -p tcp --dport 8081 -j DNAT --to-destination 10.20.0.3:22
```

**Z clienta:**
```bash
nc -zv 10.10.0.2 8081
```

**Očekávaný výstup:**
```
Connection to 10.10.0.2 8081 port [tcp/*] succeeded!
```

> Router překládá port 8081 na server:22.

---

### Úkol 4.6 – Odchozí NAT pouze pro určité cíle

**Na routeru:**
```bash
iptables -t nat -A POSTROUTING -d 10.20.0.3 -s 10.10.0.0/24 -j SNAT --to-source 10.20.0.2
```

**Z clienta:**
```bash
nc -zv 10.20.0.3 22
```

**Na serveru:**
```bash
tcpdump -n -i eth0 tcp
```

**Očekávaný výstup:**
```
10.20.0.2.55321 > 10.20.0.3.22: Flags [S], seq 123456789, win 64240
```

> SNAT se uplatní pouze pro cílovou IP 10.20.0.3.

---

### Úkol 4.7 – Přesměrování interního provozu (hairpin NAT)

**Na routeru:**
```bash
iptables -t nat -A PREROUTING -d 10.10.0.2 -p tcp --dport 8080 -j DNAT --to-destination 10.20.0.3:80
iptables -t nat -A POSTROUTING -s 10.10.0.0/24 -d 10.20.0.3 -j SNAT --to-source 10.10.0.2
```

**Z clienta:**
```bash
nc -zv 10.10.0.2 8080
```

**Očekávaný výstup:**
```
Connection to 10.10.0.2 8080 port [tcp/http-alt] succeeded!
```

> Klient se připojuje na router jako na „vlastní veřejnou IP“ a router přesměrovává zpět do interní sítě.

---

### Úkol 4.8 – Odstranění pravidel a kontrola statistik

**Na routeru:**
```bash
iptables -L -v -n
iptables -t nat -L -v -n
iptables -F
iptables -t nat -F
```

> Zobrazí se počty paketů pro každé pravidlo a poté se vyčistí všechny tabulky.
