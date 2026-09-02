#!/usr/bin/env bash

PROOF_TAG="${PROOF_TAG:-vpn-gcore-experiment}"

proof_warn() {
  printf '%s\n' "$*" >&2
}

proof_slug() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_'
}

proof_json_update() {
  local file="$1" script="$2" tmp
  tmp=$(mktemp)
  python3 - "$file" "$script" "${@:3}" >"$tmp" <<'PY'
import json
import sys

path, script = sys.argv[1], sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except FileNotFoundError:
    data = {}

namespace = {"data": data, "args": sys.argv[3:]}
exec(script, {"__builtins__": {"__import__": __import__, "int": int, "str": str, "len": len}}, namespace)
json.dump(data, sys.stdout, indent=2, sort_keys=True)
sys.stdout.write("\n")
PY
  mv "$tmp" "$file"
}

proof_init_state() {
  local run_dir="$1" region="$2" size="$3" image="$4" max_budget_usd="$5" max_lifecycle_days="$6" xray_version="${7:-}"
  mkdir -p "$run_dir"
  python3 - "$run_dir/state.json" "$region" "$size" "$image" "$max_budget_usd" "$max_lifecycle_days" "$xray_version" <<'PY'
import datetime as dt
import json
import sys

path, region, size, image, max_budget, max_days, xray_version = sys.argv[1:]
created = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
data = {
    "schema_version": 1,
    "state": "initialized",
    "created_at_utc": created,
    "updated_at_utc": created,
    "region": region,
    "size": size,
    "image": image,
    "max_budget_usd": int(max_budget),
    "max_lifecycle_days": int(max_days),
    "ownership_tag": "vpn-gcore-experiment",
    "outcomes": {},
}
if xray_version:
    data["xray_version"] = xray_version
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY
}

proof_record_outcome() {
  local run_dir="$1" name="$2" exit_code="$3"
  proof_json_update "$run_dir/state.json" '
import datetime as dt
name, code = args[0], int(args[1])
data.setdefault("outcomes", {})[name] = {
    "exit_code": code,
    "passed": code == 0,
    "recorded_at_utc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
}
data["updated_at_utc"] = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
' "$name" "$exit_code"
}

proof_record_created() {
  local run_dir="$1" droplet_id="$2" droplet_name="$3" region="$4" size="$5"
  proof_json_update "$run_dir/state.json" '
import datetime as dt
droplet_id, name, region, size = args
data["state"] = "created"
data["droplet_id"] = str(droplet_id)
data["droplet_name"] = name
data["region"] = region
data["size"] = size
data["updated_at_utc"] = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
' "$droplet_id" "$droplet_name" "$region" "$size"
}

proof_record_ssh_key() {
  local run_dir="$1" key_id="$2" uploaded="$3"
  proof_json_update "$run_dir/state.json" '
import datetime as dt
key_id, uploaded = args
data["ssh_key_id"] = str(key_id)
data["ssh_key_uploaded_by_lifecycle"] = uploaded == "1"
data["updated_at_utc"] = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
' "$key_id" "$uploaded"
}

proof_record_destroyed() {
  local run_dir="$1"
  proof_json_update "$run_dir/state.json" '
import datetime as dt
data["state"] = "destroyed"
data["destroyed_at_utc"] = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
data["updated_at_utc"] = data["destroyed_at_utc"]
'
}

proof_forget_env_keys() {
  local env_file="$1"; shift
  local tmp
  tmp=$(mktemp)
  if [[ -f "$env_file" ]]; then
    python3 - "$env_file" "$@" >"$tmp" <<'PY'
import sys

env_file = sys.argv[1]
keys = set(sys.argv[2:])
with open(env_file, encoding="utf-8") as fh:
    for line in fh:
        key = line.split("=", 1)[0]
        if key not in keys:
            sys.stdout.write(line)
PY
    mv "$tmp" "$env_file"
    chmod 600 "$env_file"
  else
    rm -f "$tmp"
  fi
}

proof_capture() {
  local run_dir="$1" name="$2"; shift 2
  local safe output status
  mkdir -p "$run_dir"
  safe="$(proof_slug "$name")"
  output="$run_dir/$safe.txt"

  printf '\n===== %s =====\n' "$name" >>"$run_dir/session.log"
  (
    printf '$'
    printf ' %q' "$@"
    printf '\n'
    "$@"
    status=$?
    printf '\nexit_code=%s\n' "$status"
    exit "$status"
  ) 2>&1 | tee "$output" >>"$run_dir/session.log"
  status=${PIPESTATUS[0]}
  if [[ -f "$run_dir/state.json" ]]; then
    proof_record_outcome "$run_dir" "$name" "$status"
  fi
  return "$status"
}

proof_verify_protected_baseline() {
  local protected_ids_file="$1" live_json_file="$2"
  python3 - "$protected_ids_file" "$live_json_file" <<'PY'
import json
import sys

protected_path, live_path = sys.argv[1:]
protected = {line.strip() for line in open(protected_path, encoding="utf-8") if line.strip()}
live = json.load(open(live_path, encoding="utf-8"))
ids = {str(d["id"]) for d in live.get("droplets", [])}

if len(ids) != len(protected):
    print(f"live count ({len(ids)}) does not match protected baseline ({len(protected)})", file=sys.stderr)
    sys.exit(1)

unknown = sorted(ids - protected)
if unknown:
    print(f"unknown Droplet {unknown[0]} on account", file=sys.stderr)
    sys.exit(1)

missing = sorted(protected - ids)
if missing:
    print(f"protected Droplet {missing[0]} is missing from account", file=sys.stderr)
    sys.exit(1)
PY
}

proof_verify_protected_baseline_json() {
  local protected_ids="$1" live_json_file="$2" protected_file
  protected_file=$(mktemp)
  printf '%s\n' "$protected_ids" >"$protected_file"
  proof_verify_protected_baseline "$protected_file" "$live_json_file"
  local status=$?
  rm -f "$protected_file"
  return "$status"
}

proof_verify_destroy_boundary() {
  local state_file="$1" protected_ids_file="$2" live_json_file="$3" droplet_id="$4"
  python3 - "$state_file" "$protected_ids_file" "$live_json_file" "$droplet_id" "$PROOF_TAG" <<'PY'
import json
import sys

state_path, protected_path, live_path, target_id, required_tag = sys.argv[1:]
state = json.load(open(state_path, encoding="utf-8"))
protected = {line.strip() for line in open(protected_path, encoding="utf-8") if line.strip()}
live = json.load(open(live_path, encoding="utf-8"))
droplets = live.get("droplets", [])
ids = {str(d["id"]) for d in droplets}
target = next((d for d in droplets if str(d.get("id")) == target_id), None)

if target_id in protected:
    print(f"target Droplet {target_id} is in the protected baseline; refusing destroy", file=sys.stderr)
    sys.exit(1)

if target is None:
    print(f"target Droplet {target_id} is not present; verify baseline by hand", file=sys.stderr)
    sys.exit(1)

if target_id != str(state.get("droplet_id", "")):
    print(f"target Droplet {target_id} does not match recorded lifecycle", file=sys.stderr)
    sys.exit(1)

if required_tag not in target.get("tags", []):
    print(f"target Droplet {target_id} is missing required ownership tag {required_tag}", file=sys.stderr)
    sys.exit(1)

checks = [
    ("name", target.get("name"), state.get("droplet_name")),
    ("region", target.get("region", {}).get("slug"), state.get("region")),
    ("size", target.get("size_slug"), state.get("size")),
]
for label, actual, expected in checks:
    if str(actual) != str(expected):
        print(f"{label} mismatch for target Droplet {target_id}: expected {expected}, got {actual}", file=sys.stderr)
        sys.exit(1)

remaining = ids - {target_id}
if remaining != protected:
    print("non-target Droplets do not match the protected baseline; refusing destroy", file=sys.stderr)
    sys.exit(1)
PY
}

proof_recovery_plan() {
  local state_file="$1" protected_ids_file="$2" live_droplet_json_file="$3"
  python3 - "$state_file" "$protected_ids_file" "$live_droplet_json_file" "$PROOF_TAG" <<'PY'
import json
import sys

state_path, protected_path, live_path, tag = sys.argv[1:]
state = json.load(open(state_path, encoding="utf-8"))
protected = {line.strip() for line in open(protected_path, encoding="utf-8") if line.strip()}
live = json.load(open(live_path, encoding="utf-8")).get("droplet")

expected_id = str(state.get("droplet_id", ""))
if not expected_id:
    print("no created lifecycle is recorded; start a new authorized proof", file=sys.stderr)
    sys.exit(1)

if expected_id in protected:
    print(f"recorded Droplet {expected_id} is in the protected baseline; stop and reconcile by hand", file=sys.stderr)
    sys.exit(1)

if not live:
    print(f"recorded Droplet {expected_id} is absent; mark lifecycle destroyed after baseline verification")
    sys.exit(0)

live_id = str(live.get("id", ""))
if live_id != expected_id:
    print(f"live Droplet id {live_id} does not match recorded lifecycle {expected_id}", file=sys.stderr)
    sys.exit(1)

if tag not in live.get("tags", []):
    print(f"recorded Droplet {expected_id} is missing required ownership tag {tag}; stop and reconcile by hand", file=sys.stderr)
    sys.exit(1)

checks = [
    ("name", live.get("name"), state.get("droplet_name")),
    ("region", live.get("region", {}).get("slug"), state.get("region")),
    ("size", live.get("size_slug"), state.get("size")),
]
for label, actual, expected in checks:
    if str(actual) != str(expected):
        print(f"{label} mismatch for recorded Droplet {expected_id}: expected {expected}, got {actual}", file=sys.stderr)
        sys.exit(1)

print(f"resume exact owned lifecycle {expected_id}; destroy with guarded single-resource path when measurements are complete")
PY
}

proof_enforce_lifecycle_bounds() {
  local state_file="$1"
  python3 - "$state_file" <<'PY'
import datetime as dt
import json
import sys

state = json.load(open(sys.argv[1], encoding="utf-8"))
created_raw = state.get("created_at_utc")
max_days = int(state.get("max_lifecycle_days", 0))
max_budget = int(state.get("max_budget_usd", 0))
size = state.get("size", "unknown")

hourly_prices = {
    "s-1vcpu-1gb": 0.00893,
    "s-1vcpu-2gb": 0.01786,
    "s-2vcpu-2gb": 0.02679,
}
price_hourly = hourly_prices.get(size)

if not created_raw or max_days <= 0 or max_budget <= 0:
    print("lifecycle bounds are missing from state; stop before mutation", file=sys.stderr)
    sys.exit(1)

created = dt.datetime.fromisoformat(created_raw)
now = dt.datetime.now(dt.timezone.utc)
age_hours = max((now - created).total_seconds() / 3600, 0)
if age_hours > max_days * 24:
    print(f"proof lifecycle is older than {max_days} days; destroy only, then start over", file=sys.stderr)
    sys.exit(1)

if price_hourly is not None and age_hours * price_hourly > max_budget:
    print(f"estimated proof cost exceeds USD {max_budget}; destroy only, then start over", file=sys.stderr)
    sys.exit(1)
PY
}

proof_write_manifest() {
  local run_dir="$1" invalid_reason="${2:-}"
  python3 - "$run_dir" "$invalid_reason" <<'PY'
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import sys

run_dir, invalid_reason = sys.argv[1:]
state_path = os.path.join(run_dir, "state.json")
state = json.load(open(state_path, encoding="utf-8"))

captures = []
for name in sorted(os.listdir(run_dir)):
    path = os.path.join(run_dir, name)
    if not name.endswith((".txt", ".json")) or name in {"manifest.json", "state.json", "path-state.txt"} or not os.path.isfile(path):
        continue
    with open(path, "rb") as fh:
        digest = hashlib.sha256(fh.read()).hexdigest()
    captures.append({"file": name, "sha256": digest})

def version(cmd):
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=5, check=False)
        first = proc.stdout.splitlines()[0] if proc.stdout.splitlines() else ""
        return {"command": cmd, "exit_code": proc.returncode, "output": first[:160]}
    except Exception as exc:
        return {"command": cmd, "exit_code": 127, "output": type(exc).__name__}

manifest = {
    key: state[key]
    for key in (
        "schema_version",
        "state",
        "created_at_utc",
        "updated_at_utc",
        "destroyed_at_utc",
        "region",
        "size",
        "image",
        "max_budget_usd",
        "max_lifecycle_days",
        "ownership_tag",
        "xray_version",
        "outcomes",
    )
    if key in state
}
manifest["resource_identity"] = "redacted"
manifest["manifest_created_at_utc"] = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
manifest["invalid_session_reason"] = invalid_reason
manifest["captures"] = captures
manifest["versions"] = {
    "bash": version(["bash", "--version"]),
    "python3": version(["python3", "--version"]),
    "curl": version(["curl", "--version"]),
    "ssh": version(["ssh", "-V"]),
}

encoded = json.dumps(manifest, indent=2, sort_keys=True)
encoded = re.sub(r"\b(?:\d{1,3}\.){3}\d{1,3}\b", "<redacted-ipv4>", encoded)
with open(os.path.join(run_dir, "manifest.json"), "w", encoding="utf-8") as fh:
    fh.write(encoded)
    fh.write("\n")
PY
}

proof_require_mutation_authorized() {
  local action="$1"
  if [[ "${PROOF_DRY_RUN:-0}" == 1 ]]; then
    printf 'DRY RUN: %s\n' "$action"
    return 2
  fi
  if [[ "${PROOF_CLOUD_AUTHORIZED:-0}" != 1 ]]; then
    proof_warn "cloud mutation not authorized: $action"
    return 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  printf 'proof-lifecycle.sh is a library; source it from a guarded workflow.\n' >&2
  exit 64
fi
