#!/usr/bin/env bash
# Migrates a running nginx-proxy-manager (jc21) to this NPMplus stack.
#
#   ./migrate-from-npm.sh check     [options]   checks only, changes nothing
#   ./migrate-from-npm.sh migrate   [options]   backup, stop NPM, copy data, start NPMplus
#   ./migrate-from-npm.sh rollback              stop NPMplus, start the old NPM again
#   ./migrate-from-npm.sh finish                remove the old NPM, its networks and leftovers
#
# Options:
#   -f <file>   compose file of the variant (default: docker-compose.yml)
#   -o <name>   name of the old NPM container (default: detected by image)
#   -y          don't ask for confirmation
#
# The old data is only read, never changed: rollback works until "finish".
# Details: README.md, section "Migrating from nginx-proxy-manager".
set -euo pipefail

cd "$(dirname "$0")"
STATE_DIR=.migration
STATE=$STATE_DIR/state
OVERRIDE=$STATE_DIR/override.yml
HELPER=alpine:3.24
MIN_ENGINE=28.0.0
MIN_COMPOSE=2.33.1
HEALTH_TIMEOUT=600   # the first start migrates the database and certificates

FILE=docker-compose.yml
OLD=""
YES=0

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ok\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; WARNINGS=$((WARNINGS + 1)); }
die()  { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; exit 1; }
WARNINGS=0

confirm() {
  [ "$YES" -eq 1 ] && return 0
  printf '%s [y/N] ' "$1"
  read -r answer < /dev/tty
  [ "$answer" = "y" ] || [ "$answer" = "Y" ] || die "aborted"
}

# ---------------------------------------------------------------- helpers

# Value of a variable from .env (last match wins, quotes removed), else the default
env_get() {
  local v
  v=$(grep -E "^$1=" .env 2>/dev/null | tail -n 1 | cut -d= -f2- || true)
  v=${v%\"}; v=${v#\"}; v=${v%\'}; v=${v#\'}
  printf '%s' "${v:-$2}"
}

version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]; }

dc() { docker compose -p "$PROJECT" "$@"; }

app_id() { dc -f "$FILE" ps -q app; }

wait_healthy() {
  local id status waited=0
  id=$(app_id)
  [ -n "$id" ] || die "NPMplus container not found"
  while :; do
    status=$(docker inspect -f '{{.State.Health.Status}}' "$id" 2>/dev/null || echo missing)
    [ "$status" = "healthy" ] && return 0
    [ "$waited" -ge "$HEALTH_TIMEOUT" ] && return 1
    sleep 5; waited=$((waited + 5))
  done
}

# Networks of a container, without host/none
container_networks() {
  docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' "$1" \
    | grep -v -E '^(host|none)?$' || true
}

# Containers in a network (running and stopped), except the given ones
network_members() {
  local net=$1 c; shift
  for c in $(docker ps -a --filter "network=$net" --format '{{.Names}}'); do
    printf '%s\n' "$@" | grep -q -x -F "$c" || echo "$c"
  done
}

# Aliases of a container in a network
aliases_in() {
  docker inspect -f "{{with index .NetworkSettings.Networks \"$2\"}}{{join .Aliases \" \"}}{{end}}" "$1"
}

# Prints "first last" of an IPv4 CIDR as integers (%.0f: mawk's %d stops at 2^31)
cidr_range() {
  awk -F'[./]' '{ ip = (($1 * 256 + $2) * 256 + $3) * 256 + $4; n = 2 ^ (32 - $5)
                  s = ip - ip % n; printf "%.0f %.0f\n", s, s + n - 1 }' <<<"$1"
}

overlaps() {
  local a b
  read -r a1 a2 <<<"$(cidr_range "$1")"
  read -r b1 b2 <<<"$(cidr_range "$2")"
  [ "$a1" -le "$b2" ] && [ "$b1" -le "$a2" ]
}

state_get() { grep -E "^$1=" "$STATE" | cut -d= -f2-; }

# ---------------------------------------------------------------- arguments

CMD=${1:-}
[ -n "$CMD" ] && shift
while getopts "f:o:y" opt; do
  case $opt in
    f) FILE=$OPTARG ;;
    o) OLD=$OPTARG ;;
    y) YES=1 ;;
    *) die "unknown option" ;;
  esac
done

[ -f "$FILE" ] || die "$FILE not found"

# Compose project name: COMPOSE_PROJECT_NAME or the folder name, normalised like Compose does
PROJECT=${COMPOSE_PROJECT_NAME:-$(env_get COMPOSE_PROJECT_NAME "")}
PROJECT=${PROJECT:-$(basename "$PWD")}
PROJECT=$(printf '%s' "$PROJECT" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')

NPM_NET=$(env_get NPM_PROXY_NETWORK npm-proxy)
NPM_PREFIX=$(env_get NPM_PROXY_NET_PREFIX 172.30.0)
NPM_BRIDGE=$(env_get NPM_PROXY_BRIDGE br-npm)
SOCK_NET=$(env_get SOCKET_PROXY_NETWORK socket-proxy)
SOCK_PREFIX=$(env_get SOCKET_PROXY_NET_PREFIX 172.31.0)
SOCK_BRIDGE=$(env_get SOCKET_PROXY_BRIDGE br-sockprx)
APP_DOMAIN=$(env_get APP_DOMAIN "")
SERVICE_USER=$(env_get NPM_SERVICE_USER "")
DATA_VOL=${PROJECT}_app-data
LE_VOL=${PROJECT}_migrate-letsencrypt

# ---------------------------------------------------------------- checks

find_old() {
  if [ -z "$OLD" ]; then
    local found
    found=$(docker ps -a --format '{{.Names}} {{.Image}}' | awk '$2 ~ /(^|\/)jc21\/nginx-proxy-manager(:|$)/ { print $1 }')
    [ -n "$found" ] || die "no nginx-proxy-manager container found, pass it with -o <name>"
    [ "$(wc -l <<<"$found")" -eq 1 ] || die "several NPM containers found, choose one with -o: $(tr '\n' ' ' <<<"$found")"
    OLD=$found
  fi
  docker inspect "$OLD" >/dev/null 2>&1 || die "container $OLD not found"
}

# Does an existing network match what the compose file would create?
network_matches() {
  local net=$1 bridge=$2 prefix=$3 got
  got=$(docker network inspect -f '{{index .Options "com.docker.network.bridge.name"}} {{range .IPAM.Config}}{{.Subnet}}{{end}} {{index .Options "com.docker.network.bridge.enable_icc"}}' "$net")
  [ "$got" = "$bridge $prefix.0/24 false" ]
}

NPM_NET_REBUILD=0

preflight() {
  info "Requirements"
  [ -f .env ] || die ".env missing: copy .env.example and fill it in first"
  [ -n "$APP_DOMAIN" ] && [ -n "$SERVICE_USER" ] || die "APP_DOMAIN and NPM_SERVICE_USER must be set in .env"
  local engine compose
  engine=$(docker version -f '{{.Server.Version}}')
  compose=$(docker compose version --short | sed 's/^v//')
  version_ge "$engine" "$MIN_ENGINE" || die "Docker Engine $engine is too old, $MIN_ENGINE or newer is needed"
  version_ge "$compose" "$MIN_COMPOSE" || die "Docker Compose $compose is too old, $MIN_COMPOSE or newer is needed"
  ok "Docker Engine $engine, Compose $compose"
  if [ "$(uname -m)" = "x86_64" ] && ! grep -q -w sse4_2 /proc/cpuinfo; then
    die "CPU is not x86-64-v2, NPMplus does not run on it"
  fi
  dc -f "$FILE" config -q || die "$FILE is not valid with this .env"
  ok "$FILE is valid, project name: $PROJECT"

  info "Old nginx-proxy-manager"
  find_old
  ok "container: $OLD ($(docker inspect -f '{{.Config.Image}}, {{.State.Status}}' "$OLD"))"
  [ "$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$OLD")" != "$PROJECT" ] \
    || die "$OLD belongs to the Compose project $PROJECT as well, Compose would replace it. Set COMPOSE_PROJECT_NAME to another name"
  docker inspect -f '{{range .Mounts}}{{.Destination}}{{"\n"}}{{end}}' "$OLD" | grep -q -x /data \
    || die "$OLD has no mount at /data, there is nothing to migrate"
  docker inspect -f '{{range .Mounts}}{{.Destination}}{{"\n"}}{{end}}' "$OLD" | grep -q -x /etc/letsencrypt \
    || warn "$OLD has no mount at /etc/letsencrypt, certificates are issued again"
  if docker inspect -f '{{range .Config.Env}}{{.}}{{"\n"}}{{end}}' "$OLD" | grep -q -E '^DB_(MYSQL|POSTGRES)_HOST='; then
    die "$OLD uses MySQL/MariaDB/PostgreSQL. NPMplus only supports SQLite: move the data to a SQLite database first, or set up NPMplus fresh"
  fi
  ok "SQLite database"
  OLD_NETS=$(container_networks "$OLD")
  [ -n "$OLD_NETS" ] && ok "networks: $(tr '\n' ' ' <<<"$OLD_NETS")"

  info "Networks of the new stack"
  local net bridge prefix subnet name
  for net in "$NPM_NET" "$SOCK_NET"; do
    if [ "$net" = "$NPM_NET" ]; then bridge=$NPM_BRIDGE; prefix=$NPM_PREFIX; else bridge=$SOCK_BRIDGE; prefix=$SOCK_PREFIX; fi
    docker network inspect "$net" >/dev/null 2>&1 || { ok "$net: will be created ($prefix.0/24, $bridge)"; continue; }
    if network_matches "$net" "$bridge" "$prefix"; then
      ok "$net: exists with the right settings"
    elif [ "$net" = "$NPM_NET" ]; then
      NPM_NET_REBUILD=1
      warn "$net exists with other settings (bridge/subnet/ICC). It is rebuilt and every container in it is reconnected with its aliases. In the new network, containers can't reach each other (an app that talks to its database through it breaks), have no internet (apps need egress) and get new IPs. Containers: $(network_members "$net" "$OLD" | tr '\n' ' ')"
    else
      die "$net exists with other settings. Remove it or set SOCKET_PROXY_NETWORK to another name"
    fi
  done
  # Subnet collisions with other networks
  # shellcheck disable=SC2046  # one argument per network ID
  while read -r name subnet; do
    [ -n "$subnet" ] && [[ $subnet != *:* ]] || continue
    if [ "$name" != "$SOCK_NET" ] && overlaps "$subnet" "$SOCK_PREFIX.0/24"; then
      die "subnet $SOCK_PREFIX.0/24 collides with network $name ($subnet): set SOCKET_PROXY_NET_PREFIX"
    fi
    if [ "$name" != "$NPM_NET" ] && overlaps "$subnet" "$NPM_PREFIX.0/24"; then
      die "subnet $NPM_PREFIX.0/24 collides with network $name ($subnet): set NPM_PROXY_NET_PREFIX"
    fi
  done < <(docker network inspect -f '{{.Name}}{{range .IPAM.Config}} {{.Subnet}}{{end}}' $(docker network ls -q) \
             | awk '{ for (i = 2; i <= NF; i++) print $1, $i }')
  ok "no subnet collisions"

  info "New volume"
  if docker volume inspect "$DATA_VOL" >/dev/null 2>&1; then
    docker run --rm -v "$DATA_VOL":/to:ro "$HELPER" sh -c '[ -z "$(ls -A /to)" ]' \
      || die "volume $DATA_VOL already contains data. Remove it (docker volume rm $DATA_VOL) if it's left over from a failed attempt"
  fi
  ok "$DATA_VOL is empty or new"

  analyse_db
}

# Reads the old database and reports what needs attention. Read-only, never fatal.
analyse_db() {
  info "Proxy hosts and certificates of the old NPM"
  local out
  # shellcheck disable=SC2016
  if ! out=$(docker run --rm --volumes-from "$OLD":ro "$HELPER" sh -c '
      apk add -q --no-cache sqlite >/dev/null 2>&1 || exit 2
      db="file:/data/database.sqlite?immutable=1"
      echo "## hosts"
      sqlite3 -separator "|" "$db" "SELECT domain_names, forward_scheme, forward_host, forward_port FROM proxy_host WHERE is_deleted = 0"
      echo "## certs"
      sqlite3 -separator "|" "$db" "SELECT nice_name, meta FROM certificate WHERE is_deleted = 0 AND provider = '\''letsencrypt'\''"
      echo "## users"
      sqlite3 "$db" "SELECT email FROM user WHERE is_deleted = 0"' 2>/dev/null); then
    warn "could not read the database (no internet for the helper container?), check hosts by hand"
    return 0
  fi

  local section="" line domains host n_hosts=0 n_ip=0 user_found=0
  while IFS= read -r line; do
    case $line in "## "*) section=${line#\#\# }; continue ;; esac
    case $section in
      hosts)
        n_hosts=$((n_hosts + 1))
        domains=$(cut -d'|' -f1 <<<"$line" | tr -d '[]"' | tr ',' ' ')
        host=$(cut -d'|' -f3 <<<"$line")
        if [[ " $domains " == *" $APP_DOMAIN "* ]]; then
          warn "proxy host $domains uses APP_DOMAIN: the sync creates its own host for it. Delete this one after the migration"
        fi
        if [[ $host =~ ^[0-9.]+$ ]]; then
          n_ip=$((n_ip + 1))
          [ "$NPM_NET_REBUILD" -eq 1 ] && warn "proxy host $domains forwards to the IP $host, which changes when $NPM_NET is rebuilt"
        fi
        ;;
      certs)
        if grep -q -E '"dns_provider":"(he|dnspod|online|powerdns|digitalocean|beget|route53)"' <<<"$line"; then
          warn "certificate $(cut -d'|' -f1 <<<"$line") uses a DNS provider NPMplus replaced or dropped: create it again after the migration"
        fi
        ;;
      users)
        [ "$line" = "$SERVICE_USER" ] && user_found=1
        ;;
    esac
  done <<<"$out"
  ok "$n_hosts proxy hosts, $n_ip of them forward to an IP (works while NPMplus stays in the old networks)"
  if [ "$user_found" -eq 0 ]; then
    warn "user $SERVICE_USER does not exist in the old database. INITIAL_ADMIN_* only applies to a fresh install, so create it in the UI after the migration (password = NPM_SERVICE_PASSWORD). Until then docker-sync stays unhealthy"
  else
    ok "user $SERVICE_USER exists, its password must equal NPM_SERVICE_PASSWORD"
  fi
}

# ---------------------------------------------------------------- commands

cmd_check() {
  preflight
  echo
  if [ "$WARNINGS" -eq 0 ]; then info "ready for: $0 migrate -f $FILE"
  else info "$WARNINGS warning(s), read them before: $0 migrate -f $FILE"; fi
}

cmd_migrate() {
  [ ! -f "$STATE" ] || die "a migration is already in progress ($STATE): finish or roll back first"
  preflight
  echo
  info "Plan: backup → stop $OLD → copy data → start NPMplus. Websites are offline for 1–3 minutes."
  confirm "Start the migration?"

  info "Pulling images (before the downtime)"
  dc -f "$FILE" pull -q

  info "Backup of /data and /etc/letsencrypt"
  mkdir -p "$STATE_DIR/backup"
  local backup ts
  ts=$(date +%Y%m%d-%H%M%S)
  backup=$STATE_DIR/backup/npm-$ts.tar.gz
  docker run --rm --volumes-from "$OLD":ro -v "$PWD/$STATE_DIR/backup":/backup "$HELPER" \
    sh -c "tar czf /backup/npm-$ts.tar.gz \$(ls -d /data /etc/letsencrypt 2>/dev/null)"
  ok "$backup"

  {
    echo "OLD=$OLD"
    echo "FILE=$FILE"
    echo "OLD_NETS=$(tr '\n' ' ' <<<"$OLD_NETS")"
    echo "NPM_NET_REBUILD=$NPM_NET_REBUILD"
  } > "$STATE"

  info "Stopping $OLD (downtime starts)"
  docker stop "$OLD" >/dev/null
  ok "stopped, its data stays untouched"
  # shellcheck disable=SC2154  # rc is set inside the trap
  trap 'rc=$?; [ "$rc" -eq 0 ] || printf "\nMigration failed. Back to the old NPM: %s rollback\n" "$0" >&2' EXIT

  if [ "$NPM_NET_REBUILD" -eq 1 ]; then
    info "Rebuilding $NPM_NET"
    local c aliases args
    : > "$STATE_DIR/reconnect"
    for c in $(network_members "$NPM_NET"); do
      echo "$c $(aliases_in "$c" "$NPM_NET")" >> "$STATE_DIR/reconnect"
    done
    while read -r c _; do docker network disconnect -f "$NPM_NET" "$c"; done < "$STATE_DIR/reconnect"
    docker network rm "$NPM_NET" >/dev/null
    ok "removed, $(grep -c . "$STATE_DIR/reconnect") container(s) remembered"
  fi

  info "Creating the stack"
  dc -f "$FILE" create

  if [ "$NPM_NET_REBUILD" -eq 1 ]; then
    while read -r c aliases; do
      [ "$c" = "$OLD" ] && continue
      args=()
      for a in $aliases; do args+=(--alias "$a"); done
      docker network connect "${args[@]}" "$NPM_NET" "$c"
    done < "$STATE_DIR/reconnect"
    ok "containers reconnected to the new $NPM_NET"
  fi

  info "Copying data"
  docker run --rm --volumes-from "$OLD":ro -v "$DATA_VOL":/to "$HELPER" sh -c 'cp -a /data/. /to/'
  docker volume create "$LE_VOL" >/dev/null
  docker run --rm --volumes-from "$OLD":ro -v "$LE_VOL":/to "$HELPER" \
    sh -c '[ ! -d /etc/letsencrypt ] || cp -a /etc/letsencrypt/. /to/'
  ok "copied into $DATA_VOL and $LE_VOL"

  # First start as upstream describes it: old /etc/letsencrypt mounted, NPMplus moves it to /data.
  # The extra capabilities only cover moving and re-owning the old files, the normal start drops them.
  cat > "$OVERRIDE" <<EOF
services:
  app:
    cap_add: [CHOWN, DAC_OVERRIDE, FOWNER]
    volumes:
      - type: volume
        source: migrate-letsencrypt
        target: /etc/letsencrypt
volumes:
  migrate-letsencrypt:
    name: $LE_VOL
    external: true
EOF
  info "First start of NPMplus (migrates the data)"
  dc -f "$FILE" -f "$OVERRIDE" up -d
  wait_healthy || die "NPMplus did not become healthy. Logs: docker compose -p $PROJECT -f $FILE logs app — back with: $0 rollback"
  ok "migrated"

  info "Normal start without the migration mount"
  dc -f "$FILE" up -d
  wait_healthy || die "NPMplus did not become healthy. Logs: docker compose -p $PROJECT -f $FILE logs app — back with: $0 rollback"
  ok "NPMplus is healthy"

  connect_old_networks

  echo
  info "Done. Check now:"
  echo "    - every website, and https://$APP_DOMAIN (admin UI)"
  echo "    - docker compose -p $PROJECT -f $FILE ps   (all services healthy?)"
  echo "    - in the UI: hosts with custom certificates or DNS challenges"
  echo "  Problem? $0 rollback"
  echo "  Once every app is in $NPM_NET: $0 finish"
}

# Puts NPMplus into the old networks, so apps there stay reachable. Runtime only:
# it survives restarts, but not a recreate of the container (see README).
connect_old_networks() {
  local id net
  id=$(app_id)
  for net in $(state_get OLD_NETS); do
    [ "$net" = "$NPM_NET" ] && continue
    docker network inspect "$net" >/dev/null 2>&1 || continue
    docker network connect "$net" "$id" 2>/dev/null || true
    ok "NPMplus also joined $net (temporary)"
  done
}

cmd_rollback() {
  [ -f "$STATE" ] || die "no migration in progress"
  OLD=$(state_get OLD); FILE=$(state_get FILE)
  confirm "Stop NPMplus and start $OLD again?"
  # socket-proxy and firewall keep running: other stacks may already use them
  info "Stopping NPMplus"
  # shellcheck disable=SC2046  # one argument per service
  dc -f "$FILE" stop $(dc -f "$FILE" config --services | grep -v -x -e socket-proxy -e firewall)
  if [ "$(state_get NPM_NET_REBUILD)" = "1" ]; then
    # The old network is gone: the old NPM joins the new one, where the apps already are.
    # On NPMplus' fixed IP it gets the same firewall exceptions (reach apps, internet).
    local aliases args=()
    aliases=$(awk -v c="$OLD" '$1 == c { $1 = ""; print }' "$STATE_DIR/reconnect")
    for a in $aliases; do args+=(--alias "$a"); done
    docker network connect --ip "$NPM_PREFIX.2" "${args[@]}" "$NPM_NET" "$OLD" 2>/dev/null || true
  fi
  info "Starting $OLD"
  docker start "$OLD" >/dev/null
  ok "$OLD runs again with its unchanged data"
  rm -f "$STATE" "$OVERRIDE" "$STATE_DIR/reconnect"
  echo "  The new volumes stay until you remove them: docker volume rm $DATA_VOL $LE_VOL"
  echo "  The backup stays in $STATE_DIR/backup/"
}

cmd_finish() {
  [ -f "$STATE" ] || die "no migration in progress"
  OLD=$(state_get OLD); FILE=$(state_get FILE)
  local id net left vols
  id=$(app_id)
  for net in $(state_get OLD_NETS); do
    case $net in "$NPM_NET"|bridge) continue ;; esac   # Docker's default bridge stays anyway
    docker network inspect "$net" >/dev/null 2>&1 || continue
    left=$(network_members "$net" "$OLD" "$(docker inspect -f '{{.Name}}' "$id" | tr -d /)")
    [ -z "$left" ] || die "still in $net: $(tr '\n' ' ' <<<"$left")— move them to $NPM_NET first"
  done
  vols=$(docker inspect -f '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}' "$OLD")
  confirm "Remove $OLD, its old networks and $LE_VOL?"
  for net in $(state_get OLD_NETS); do
    [ "$net" = "$NPM_NET" ] && continue
    docker network disconnect "$net" "$id" 2>/dev/null || true
  done
  docker rm "$OLD" >/dev/null
  ok "removed $OLD"
  for net in $(state_get OLD_NETS); do
    case $net in "$NPM_NET"|bridge) continue ;; esac
    docker network rm "$net" >/dev/null 2>&1 && ok "removed network $net" || warn "network $net not removed"
  done
  docker volume rm "$LE_VOL" >/dev/null 2>&1 || true
  rm -f "$STATE" "$OVERRIDE" "$STATE_DIR/reconnect"
  ok "migration finished"
  [ -z "$vols" ] || echo "  Old volumes kept, remove them once you're sure: docker volume rm $vols"
  echo "  Backup kept: $STATE_DIR/backup/"
}

case $CMD in
  check)    cmd_check ;;
  migrate)  cmd_migrate ;;
  rollback) cmd_rollback ;;
  finish)   cmd_finish ;;
  *)        sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
