#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    echo "Usage: set-active-datacentre <dc1|dc2>" >&2
    exit 2
fi

target_dc=$1

dc1_app_ip_1=
dc1_app_ip_2=
dc2_app_ip_1=
dc2_app_ip_2=
while IFS='=' read -r name address; do
    case "$name" in
        DC1_APP_IP_1) dc1_app_ip_1=$address ;;
        DC1_APP_IP_2) dc1_app_ip_2=$address ;;
        DC2_APP_IP_1) dc2_app_ip_1=$address ;;
        DC2_APP_IP_2) dc2_app_ip_2=$address ;;
        *)
            echo "Unexpected HAProxy backend setting: $name" >&2
            exit 1
            ;;
    esac
done < /etc/ww-demo-haproxy-backends

if [[ -z "$dc1_app_ip_1" || -z "$dc1_app_ip_2" || -z "$dc2_app_ip_1" || -z "$dc2_app_ip_2" ]]; then
    echo "One or more HAProxy backend addresses are missing." >&2
    exit 1
fi

case "$target_dc" in
    dc1)
        target_servers=(dc1_app_01 dc1_app_02)
        inactive_servers=(dc2_app_01 dc2_app_02)
        target_health_urls=("http://${dc1_app_ip_1}:8080/health" "http://${dc1_app_ip_2}:8080/health")
        ;;
    dc2)
        target_servers=(dc2_app_01 dc2_app_02)
        inactive_servers=(dc1_app_01 dc1_app_02)
        target_health_urls=("http://${dc2_app_ip_1}:8080/health" "http://${dc2_app_ip_2}:8080/health")
        ;;
    *)
        echo "Target datacentre must be dc1 or dc2." >&2
        exit 2
        ;;
esac

socket=/run/haproxy/admin.sock
if [[ ! -S "$socket" ]]; then
    echo "HAProxy runtime socket is unavailable: $socket" >&2
    exit 1
fi

for health_url in "${target_health_urls[@]}"; do
    if ! curl -fsS --max-time 3 "$health_url" | grep -Fq '"status": "healthy"'; then
        echo "Target health check failed at $health_url; traffic state was not changed." >&2
        exit 1
    fi
done

for server in "${target_servers[@]}"; do
    printf 'set server demo_applications/%s state ready\n' "$server" |
        socat - "UNIX-CONNECT:$socket"
done

for server in "${inactive_servers[@]}"; do
    printf 'set server demo_applications/%s state maint\n' "$server" |
        socat - "UNIX-CONNECT:$socket"
done

printf 'Traffic target set to %s. Verify application health through the front door.\n' "$target_dc"
