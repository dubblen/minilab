FROM ubuntu:latest

RUN apt update && \
    apt install -y iproute2 iputils-ping iptables curl busybox iptables-persistent bash traceroute tcpdump netcat-traditional && \
    apt clean && rm -rf /var/lib/apt/lists/*

# Konzistentní barvy a hostname v promptu pro všechny režimy (login i non-login)
ENV TERM=xterm-256color

# 1) Společný skript s promptem
RUN cat > /etc/bashrc-common.sh <<'EOF'
# Pouze pro interaktivní shell
case $- in
  *i*) ;;
  *) return ;;
esac

# Force barevný prompt (ochrana proti případům bez TTY)
: "${TERM:=xterm-256color}"

# Prompt podle hostname
case "$(hostname)" in
  router) PS1="\[\e[1;31m\][\u@router \W]\\$\[\e[0m\] " ;;
  client) PS1="\[\e[1;32m\][\u@client \W]\\$\[\e[0m\] " ;;
  server) PS1="\[\e[1;34m\][\u@server \W]\\$\[\e[0m\] " ;;
  *)      PS1="\[\e[1;33m\][\u@\h \W]\\$\[\e[0m\] "    ;;
esac
export PS1
EOF

# 2) Zajisti načtení v login shellech
RUN echo '[ -f /etc/bashrc-common.sh ] && . /etc/bashrc-common.sh' >> /etc/profile

# 3) Zajisti načtení v non-login interaktivních shellech (global)
RUN echo '[ -f /etc/bashrc-common.sh ] && . /etc/bashrc-common.sh' >> /etc/bash.bashrc

# 4) A také pro root (kdyby bash sahal primárně do ~)
RUN printf '%s\n' \
  '[ -f /etc/bashrc-common.sh ] && . /etc/bashrc-common.sh' \
  >> /root/.bashrc

CMD ["bash", "-c", "tail -f /dev/null"]
