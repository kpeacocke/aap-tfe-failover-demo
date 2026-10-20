#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 || ! "$1" =~ ^ww-demo-(shared|dc1|dc2)$ ]]; then
    echo "Usage: $0 <ww-demo-shared|ww-demo-dc1|ww-demo-dc2>" >&2
    exit 2
fi

: "${HCP_TERRAFORM_ORGANIZATION:?Set HCP_TERRAFORM_ORGANIZATION}"
: "${TF_TOKEN_app_terraform_io:?Set TF_TOKEN_app_terraform_io}"
if [[ ! "$HCP_TERRAFORM_ORGANIZATION" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "Invalid HCP Terraform organization name." >&2
    exit 1
fi
for dependency in curl jq; do
    if ! command -v "$dependency" >/dev/null; then
        echo "Workspace initialization requires $dependency." >&2
        exit 1
    fi
done

workspace=$1
base_url="https://app.terraform.io/api/v2/organizations/$HCP_TERRAFORM_ORGANIZATION/workspaces"

request() {
    local method=$1 url=$2
    shift 2
    local response
    response=$(printf 'Authorization: Bearer %s\n' "$TF_TOKEN_app_terraform_io" |
        curl --silent --show-error --connect-timeout 10 --max-time 60 \
            --header @- --header 'Content-Type: application/vnd.api+json' \
            --request "$method" --write-out $'\n%{http_code}' "$@" "$url")
    status=${response##*$'\n'}
    body=${response%$'\n'*}
}

request GET "$base_url/$workspace"
case "$status" in
    200)
        if ! jq -e --arg name "$workspace" \
            '.data.type == "workspaces" and .data.attributes.name == $name and (.data.id | type == "string")' \
            <<< "$body" >/dev/null; then
            echo "Invalid workspace response for $workspace; initialization stopped." >&2
            exit 1
        fi
        echo "Reusing HCP Terraform workspace $workspace (settings unchanged)."
        ;;
    404)
        payload=$(jq -nc --arg name "$workspace" \
            '{data:{type:"workspaces",attributes:{name:$name,"execution-mode":"local","auto-apply":false}}}')
        request POST "$base_url" --data "$payload"
        if [[ "$status" != "201" ]]; then
            echo "Cannot create workspace $workspace (HTTP $status). Check organization name, workspace-creation permission, and organization policies." >&2
            exit 1
        fi
        if ! jq -e --arg name "$workspace" \
            '.data.type == "workspaces" and .data.attributes.name == $name and .data.attributes["execution-mode"] == "local" and (.data.id | type == "string")' \
            <<< "$body" >/dev/null; then
            echo "Workspace $workspace was created, but its local execution setting could not be verified; inspect it in HCP Terraform before continuing." >&2
            exit 1
        fi
        echo "Created HCP Terraform workspace $workspace with local execution."
        ;;
    *)
        echo "Cannot read workspace $workspace (HTTP $status). Check the HCP token and organization permissions; no workspace was created." >&2
        exit 1
        ;;
esac
