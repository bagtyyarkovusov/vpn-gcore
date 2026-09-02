#!/usr/bin/env bash
#
# vpn-gcore DigitalOcean safety guard.
#
# Source this before ANY DigitalOcean write call:
#     . scripts/do-guard.sh
#
# The account holds pre-existing Droplets belonging to unrelated projects. This
# guard makes it hard to touch them by accident. See
# docs/agents/infrastructure-safety.md for the rule it enforces.
#
# The guard holds no identifiers of its own. The protected baseline — the only
# genuinely private part — is a mode-600 file outside this repository, pointed
# at by DO_PROTECTED_IDS. The decision logic lives here so that it can be
# reviewed, tested, and version controlled.

DO_API="${DO_API:-https://api.digitalocean.com/v2}"
DO_PROTECTED_IDS="${DO_PROTECTED_IDS:-/private/tmp/vpn-gcore-do-discovery/protected-ids.txt}"
DO_EXPERIMENT_TAG="${DO_EXPERIMENT_TAG:-${PROOF_TAG:-vpn-gcore-experiment}}"

_do_token() {
  if [[ -z "${DIGITALOCEAN_ACCESS_TOKEN:-}" ]]; then
    echo "guard: DIGITALOCEAN_ACCESS_TOKEN is not set." >&2
    echo "       set -a; . /private/tmp/vpn-gcore-do-session.env; set +a" >&2
    return 1
  fi
}

# do_protected_ids — the ids that must never be destroyed.
do_protected_ids() {
  if [[ ! -s "$DO_PROTECTED_IDS" ]]; then
    echo "guard: protected baseline missing ($DO_PROTECTED_IDS)." >&2
    echo "       Capture it with the discovery wizard before any write call." >&2
    return 1
  fi
  cat "$DO_PROTECTED_IDS"
}

# do_is_protected ID — success if the Droplet is off limits.
do_is_protected() {
  local id="$1" ids
  ids=$(do_protected_ids) || return 0   # no baseline ⇒ treat everything as protected
  grep -qx "$id" <<<"$ids"
}

# do_destroy_droplet ID — the ONLY sanctioned destroy path.
# Refuses unless the Droplet is absent from the baseline AND carries the
# experiment tag, then requires typed confirmation.
do_destroy_droplet() {
  local id="${1:-}" json name tags reply
  [[ -n "$id" ]] || { echo "usage: do_destroy_droplet <droplet-id>" >&2; return 1; }
  _do_token || return 1

  if do_is_protected "$id"; then
    echo "REFUSED: Droplet $id is on the protected baseline." >&2
    echo "         It belongs to an unrelated project. Ask the user." >&2
    return 1
  fi

  json=$(curl -sS -f -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
         "$DO_API/droplets/$id") || { echo "guard: could not read Droplet $id" >&2; return 1; }
  name=$(python3 -c 'import json,sys;print(json.load(sys.stdin)["droplet"]["name"])' <<<"$json")
  tags=$(python3 -c 'import json,sys;print(",".join(json.load(sys.stdin)["droplet"].get("tags") or []))' <<<"$json")

  if [[ ",$tags," != *",$DO_EXPERIMENT_TAG,"* ]]; then
    echo "REFUSED: Droplet $id ($name) lacks the '$DO_EXPERIMENT_TAG' tag." >&2
    echo "         Only Droplets this experiment created may be destroyed." >&2
    return 1
  fi

  echo "About to DESTROY Droplet $id ($name), tags: $tags"
  read -r -p "Type the Droplet name to confirm: " reply
  [[ "$reply" == "$name" ]] || { echo "Aborted."; return 1; }

  curl -sS -f -X DELETE -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
    "$DO_API/droplets/$id" && echo "Destroyed $id ($name)."
}

# do_create_droplet_payload NAME REGION SIZE IMAGE SSH_KEY_ID — emits JSON with
# the experiment tag already attached. Creation stays a deliberate, separate act.
do_create_droplet_payload() {
  DO_EXPERIMENT_TAG="$DO_EXPERIMENT_TAG" python3 - "$@" <<'PY'
import json, os, sys
name, region, size, image, key = sys.argv[1:6]
print(json.dumps({
    "name": name, "region": region, "size": size, "image": image,
    "ssh_keys": [key], "backups": False, "ipv6": True,
    "monitoring": True, "tags": [os.environ["DO_EXPERIMENT_TAG"]],
}))
PY
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  printf 'do-guard.sh is a library; source it before any DigitalOcean write call.\n' >&2
  exit 64
fi

echo "vpn-gcore DO guard loaded."
if [[ -s "$DO_PROTECTED_IDS" ]]; then
  echo "  protected Droplets: $(wc -l < "$DO_PROTECTED_IDS" | tr -d ' ') (never delete)"
else
  echo "  WARNING: protected baseline not captured yet — all destroys will be refused."
fi
