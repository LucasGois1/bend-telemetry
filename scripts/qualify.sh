#!/bin/sh
# The qualification harness: an OpenTelemetry Collector, Grafana Tempo and
# Grafana (qualification/compose.yaml), fed over OTLP/HTTP, and the verifier
# (qualification/verify.mjs), which compares what the Collector wrote and what
# Tempo shows with the reference trace.
#
#   ./scripts/qualify.sh up                      start a fresh stack
#   ./scripts/qualify.sh run [--producer curl]   send a producer's trace and verify it
#   ./scripts/qualify.sh down                    keep the stack's logs and stop it
#
# `up` removes any previous stack, with its Tempo volume, and the evidence of
# the previous session; starts the stack with `compose up --wait`, which waits
# for Tempo's and Grafana's health checks; and then waits for the Collector's
# health endpoint from the host, since the Collector's image has no shell for
# a health check of its own. `run` checks that the stack is up and sends the
# producer's trace: the curl producer posts qualification/reference-trace.json
# to the Collector's /v1/traces as JSON and expects HTTP 200. The verifier then
# reads what the Collector wrote from the size its file had before the send,
# so that `run` can be repeated, and asks Tempo for the trace. `down` writes
# each service's log and stops the stack, removing the Tempo volume. While the
# stack runs, Grafana shows the trace at http://localhost:3000.
#
# Docker, or Podman with a compose plugin, is required, with curl and Node 22
# or newer. Evidence goes to build/qualification/: the Collector's output
# (collector/), the producer's answer, the verifier's evidence (verifier/) and
# the logs (logs/).
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
compose_file="$repo_dir/qualification/compose.yaml"
build_dir="$repo_dir/build/qualification"
collector_dir="$build_dir/collector"
collector_output="$collector_dir/traces.jsonl"
logs_dir="$build_dir/logs"
collector_url=http://127.0.0.1:4318
collector_health=http://127.0.0.1:13133/
tempo_url=http://127.0.0.1:3200

usage() {
  echo "Usage: $0 up | run [--producer curl] | down" >&2
  exit 2
}

require() {
  for command_name in "$@"; do
    command -v "$command_name" >/dev/null || { echo "Required command: $command_name" >&2; exit 1; }
  done
}

stack() {
  "$engine" compose --file "$compose_file" "$@"
}

save_logs() {
  mkdir -p "$logs_dir"
  for service in collector tempo grafana; do
    stack logs --no-color --no-log-prefix "$service" > "$logs_dir/$service.log" 2>&1 || true
  done
  stack ps --all > "$logs_dir/services.txt" 2>&1 || true
}

collector_is_healthy() {
  curl --silent --fail --output /dev/null "$collector_health"
}

up() {
  [ "$#" -eq 0 ] || usage
  require curl
  stack down --volumes --remove-orphans > /dev/null 2>&1 || true
  rm -rf "$build_dir"
  mkdir -p "$collector_dir"
  # The Collector runs as its image's own user, which must create its file here.
  chmod a+rwx "$collector_dir"
  if ! stack up --wait --wait-timeout 180; then
    save_logs
    echo "The stack did not become healthy; its logs are in $logs_dir." >&2
    exit 1
  fi
  tries=0
  until collector_is_healthy; do
    tries=$((tries + 1))
    if [ "$tries" -gt 60 ]; then
      save_logs
      echo "The Collector's health endpoint did not answer; its logs are in $logs_dir." >&2
      exit 1
    fi
    sleep 1
  done
  echo "PASS: the stack is up: OTLP at $collector_url, Tempo at $tempo_url, Grafana at http://localhost:3000"
}

run() {
  producer=curl
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --producer) [ "$#" -ge 2 ] || usage; producer=$2; shift 2 ;;
      *) usage ;;
    esac
  done
  case "$producer" in
    curl) ;;
    *) echo "Unknown producer: $producer. The producers are: curl." >&2; exit 2 ;;
  esac
  require curl node
  node_major=$(node -p 'Number(process.versions.node.split(".")[0])')
  [ "$node_major" -ge 22 ] || { echo "Node 22 or newer is required; found $(node --version)." >&2; exit 1; }
  collector_is_healthy || { echo "The stack is not up: run '$0 up' first." >&2; exit 1; }
  offset=0
  [ ! -f "$collector_output" ] || offset=$(wc -c < "$collector_output" | tr -d ' ')

  answer="$build_dir/curl-response.json"
  status=$(curl --silent --show-error --output "$answer" --write-out '%{http_code}' \
    --header 'Content-Type: application/json' \
    --data-binary "@$repo_dir/qualification/reference-trace.json" "$collector_url/v1/traces")
  if [ "$status" != 200 ]; then
    echo "FAIL: the Collector answered HTTP $status to the reference trace:" >&2
    cat "$answer" >&2
    exit 1
  fi
  echo "PASS: the Collector accepted the reference trace from curl (HTTP 200)"

  node "$repo_dir/qualification/verify.mjs" --collector-output "$collector_output" --from-byte "$offset" \
    --tempo "$tempo_url" --evidence "$build_dir/verifier"
}

down() {
  [ "$#" -eq 0 ] || usage
  save_logs
  stack down --volumes --remove-orphans
  echo "The stack is stopped; the evidence is in $build_dir."
}

[ "$#" -ge 1 ] || usage
action=$1
shift
case "$action" in up|run|down) ;; *) usage ;; esac
if docker compose version >/dev/null 2>&1; then
  engine=docker
elif podman compose version >/dev/null 2>&1; then
  engine=podman
else
  echo "Docker, or Podman with a compose plugin, is required." >&2
  exit 1
fi
"$action" "$@"
