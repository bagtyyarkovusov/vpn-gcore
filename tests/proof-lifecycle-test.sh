#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/proof-lifecycle.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_file_contains() {
  local file="$1" pattern="$2"
  grep -Eq "$pattern" "$file" || fail "$file did not contain $pattern"
}

assert_json_field() {
  local file="$1" expr="$2" expected="$3"
  local actual
  actual=$(python3 -c '
import json, sys
expr = sys.argv[1]
with open(sys.argv[2], encoding="utf-8") as fh:
    data = json.load(fh)
print(eval(expr, {"__builtins__": {"len": len}}, {"data": data}))
' "$expr" "$file")
  [[ "$actual" == "$expected" ]] || fail "$expr expected $expected got $actual"
}

test_capture_preserves_failed_probe_status() {
  local run="$TMPDIR/capture"
  mkdir -p "$run"

  set +e
  proof_capture "$run" "failing-probe" bash -c 'echo before; exit 7'
  local status=$?
  set -e

  [[ "$status" -eq 7 ]] || fail "proof_capture returned $status instead of failed command status 7"
  assert_file_contains "$run/failing-probe.txt" '^exit_code=7$'
  assert_file_contains "$run/session.log" '^exit_code=7$'
}

test_manifest_records_versions_checksums_statuses_and_redacts_ip() {
  local run="$TMPDIR/manifest"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7
  proof_record_created "$run" 555 vpn-gcore-exp-proof sfo2 s-2vcpu-2gb
  proof_record_outcome "$run" "node-ping-100" 0
  proof_record_outcome "$run" "node-tcp443-connect" 28
  printf 'active node 203.0.113.14 secret-free\n' >"$run/node-tcp443-connect.txt"
  proof_write_manifest "$run" "invalid: access control failed"

  assert_json_field "$run/manifest.json" "data['region']" "sfo2"
  assert_json_field "$run/manifest.json" "data['size']" "s-2vcpu-2gb"
  assert_json_field "$run/manifest.json" "data['max_budget_usd']" "5"
  assert_json_field "$run/manifest.json" "data['max_lifecycle_days']" "7"
  assert_json_field "$run/manifest.json" "data['invalid_session_reason']" "invalid: access control failed"
  assert_json_field "$run/manifest.json" "data['outcomes']['node-tcp443-connect']['exit_code']" "28"
  assert_json_field "$run/manifest.json" "data['outcomes']['node-tcp443-connect']['passed']" "False"
  assert_json_field "$run/manifest.json" "len(data['captures'])" "1"
  assert_json_field "$run/manifest.json" "data['resource_identity']" "redacted"
  ! grep -q '203\.0\.113\.14' "$run/manifest.json" || fail "manifest leaked an active IP address"
  ! grep -q '555' "$run/manifest.json" || fail "manifest leaked a Droplet ID"
  ! grep -q 'vpn-gcore-exp-proof' "$run/manifest.json" || fail "manifest leaked a Droplet name"
}

test_baseline_mismatch_fails_closed() {
  local protected="$TMPDIR/protected.txt" live="$TMPDIR/live.json"
  printf '100\n101\n' >"$protected"
  printf '{"droplets":[{"id":100},{"id":999}]}\n' >"$live"

  set +e
  proof_verify_protected_baseline "$protected" "$live" >"$TMPDIR/baseline.out" 2>&1
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "baseline mismatch passed"
  assert_file_contains "$TMPDIR/baseline.out" 'unknown Droplet 999'
}

test_recovery_refuses_wrong_ownership() {
  local run="$TMPDIR/recovery"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7
  proof_record_created "$run" 555 vpn-gcore-exp-proof sfo2 s-2vcpu-2gb
  printf '10\n11\n' >"$run/protected-ids.txt"
  printf '{"droplet":{"id":555,"name":"vpn-gcore-exp-proof","region":{"slug":"sfo2"},"size_slug":"s-2vcpu-2gb","tags":["other-tag"]}}\n' >"$run/live-droplet.json"

  set +e
  proof_recovery_plan "$run/state.json" "$run/protected-ids.txt" "$run/live-droplet.json" >"$TMPDIR/recovery.out" 2>&1
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "wrong ownership recovery passed"
  assert_file_contains "$TMPDIR/recovery.out" 'missing required ownership tag'
}

test_dry_run_blocks_cloud_mutation() {
  set +e
  PROOF_DRY_RUN=1 proof_require_mutation_authorized "create droplet" >"$TMPDIR/dryrun.out" 2>&1
  local status=$?
  set -e

  [[ "$status" -eq 2 ]] || fail "dry run returned $status instead of 2"
  assert_file_contains "$TMPDIR/dryrun.out" '^DRY RUN: create droplet$'
}

test_env_cleanup_removes_only_lifecycle_keys() {
  local env="$TMPDIR/run.env"
  {
    printf 'DO_REGION=sfo2\n'
    printf 'DO_DROPLET_ID=555\n'
    printf 'DO_DROPLET_IP=203.0.113.14\n'
    printf 'DO_RUN_DIR=/private/tmp/example\n'
  } >"$env"

  proof_forget_env_keys "$env" DO_DROPLET_ID DO_DROPLET_IP DO_RUN_DIR

  assert_file_contains "$env" '^DO_REGION=sfo2$'
  ! grep -q '^DO_DROPLET_ID=' "$env" || fail "old Droplet ID remained in env"
  ! grep -q '^DO_DROPLET_IP=' "$env" || fail "old Droplet IP remained in env"
  ! grep -q '^DO_RUN_DIR=' "$env" || fail "old run directory remained in env"
}

# shellcheck disable=SC2016  # these patterns are literal source text, not expansions
test_wizard_passes_pinned_xray_version_to_state() {
  local wizard="$ROOT/scripts/do-route-wizard.sh"
  assert_file_contains "$wizard" '^XRAY_VERSION="v[0-9]'
  grep -q 'proof_init_state .*"\$MAX_PROOF_LIFECYCLE_DAYS" "\$XRAY_VERSION"' "$wizard" \
    || fail "wizard does not pass XRAY_VERSION into proof_init_state"
}

test_pinned_xray_version_reaches_state_and_manifest() {
  local run="$TMPDIR/xray-version"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7 v26.6.1
  proof_record_created "$run" 555 vpn-gcore-exp-proof sfo2 s-2vcpu-2gb
  proof_write_manifest "$run" ""

  assert_json_field "$run/state.json" "data['xray_version']" "v26.6.1"
  assert_json_field "$run/manifest.json" "data['xray_version']" "v26.6.1"
}

test_manifest_omits_xray_version_when_unpinned() {
  local run="$TMPDIR/xray-version-absent"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7
  proof_write_manifest "$run" ""

  assert_json_field "$run/manifest.json" "'xray_version' in data" "False"
}

test_destroy_boundary_accepts_exact_owned_target() {
  local run="$TMPDIR/destroy-owned"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7
  proof_record_created "$run" 555 vpn-gcore-exp-proof sfo2 s-2vcpu-2gb
  printf '100\n101\n' >"$run/protected.txt"
  printf '{"droplets":[{"id":100},{"id":101},{"id":555,"name":"vpn-gcore-exp-proof","region":{"slug":"sfo2"},"size_slug":"s-2vcpu-2gb","tags":["vpn-gcore-experiment"]}]}\n' >"$run/live.json"

  proof_verify_destroy_boundary "$run/state.json" "$run/protected.txt" "$run/live.json" 555 \
    || fail "exact owned target did not pass destroy boundary"
}

test_destroy_boundary_refuses_missing_ownership_tag() {
  local run="$TMPDIR/destroy-missing-tag"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7
  proof_record_created "$run" 555 vpn-gcore-exp-proof sfo2 s-2vcpu-2gb
  printf '100\n101\n' >"$run/protected.txt"
  printf '{"droplets":[{"id":100},{"id":101},{"id":555,"name":"vpn-gcore-exp-proof","region":{"slug":"sfo2"},"size_slug":"s-2vcpu-2gb","tags":["other-tag"]}]}\n' >"$run/live.json"

  set +e
  proof_verify_destroy_boundary "$run/state.json" "$run/protected.txt" "$run/live.json" 555 >"$TMPDIR/missing-tag.out" 2>&1
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "missing ownership tag passed destroy boundary"
  assert_file_contains "$TMPDIR/missing-tag.out" 'missing required ownership tag'
}

test_destroy_boundary_refuses_identity_mismatch() {
  local run="$TMPDIR/destroy-wrong-name"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7
  proof_record_created "$run" 555 vpn-gcore-exp-proof sfo2 s-2vcpu-2gb
  printf '100\n101\n' >"$run/protected.txt"
  printf '{"droplets":[{"id":100},{"id":101},{"id":555,"name":"wrong-name","region":{"slug":"sfo2"},"size_slug":"s-2vcpu-2gb","tags":["vpn-gcore-experiment"]}]}\n' >"$run/live.json"

  set +e
  proof_verify_destroy_boundary "$run/state.json" "$run/protected.txt" "$run/live.json" 555 >"$TMPDIR/wrong-name.out" 2>&1
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "identity mismatch passed destroy boundary"
  assert_file_contains "$TMPDIR/wrong-name.out" 'name mismatch'
}

test_lifecycle_bounds_fail_when_state_is_stale() {
  local run="$TMPDIR/stale"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7
  python3 - "$run/state.json" <<'PY'
import datetime as dt
import json
import sys

path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["created_at_utc"] = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=8)).replace(microsecond=0).isoformat()
json.dump(data, open(path, "w", encoding="utf-8"), indent=2, sort_keys=True)
PY

  set +e
  proof_enforce_lifecycle_bounds "$run/state.json" >"$TMPDIR/stale.out" 2>&1
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "stale lifecycle passed bounds check"
  assert_file_contains "$TMPDIR/stale.out" 'older than 7 days'
}

test_destroy_boundary_refuses_protected_target() {
  local run="$TMPDIR/destroy-protected"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7
  proof_record_created "$run" 555 vpn-gcore-exp-proof sfo2 s-2vcpu-2gb
  printf '555\n777\n' >"$run/protected.txt"
  printf '{"droplets":[{"id":555,"name":"vpn-gcore-exp-proof","region":{"slug":"sfo2"},"size_slug":"s-2vcpu-2gb","tags":["vpn-gcore-experiment"]},{"id":777}]}\n' >"$run/live.json"

  set +e
  proof_verify_destroy_boundary "$run/state.json" "$run/protected.txt" "$run/live.json" 555 >"$TMPDIR/destroy.out" 2>&1
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "protected target destroy boundary passed"
  assert_file_contains "$TMPDIR/destroy.out" 'protected baseline'
}

test_post_destroy_baseline_requires_exact_ids() {
  local protected="$TMPDIR/post-destroy-protected.txt" live="$TMPDIR/post-destroy-live.json"
  printf '100\n101\n' >"$protected"
  printf '{"droplets":[{"id":100},{"id":999}]}\n' >"$live"

  set +e
  proof_verify_protected_baseline "$protected" "$live" >"$TMPDIR/post-destroy.out" 2>&1
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "changed baseline ids passed post-destroy verification"
  assert_file_contains "$TMPDIR/post-destroy.out" 'unknown Droplet 999'
}

main() {
  test_capture_preserves_failed_probe_status
  test_manifest_records_versions_checksums_statuses_and_redacts_ip
  test_baseline_mismatch_fails_closed
  test_recovery_refuses_wrong_ownership
  test_dry_run_blocks_cloud_mutation
  test_env_cleanup_removes_only_lifecycle_keys
  test_wizard_passes_pinned_xray_version_to_state
  test_pinned_xray_version_reaches_state_and_manifest
  test_manifest_omits_xray_version_when_unpinned
  test_destroy_boundary_accepts_exact_owned_target
  test_destroy_boundary_refuses_missing_ownership_tag
  test_destroy_boundary_refuses_identity_mismatch
  test_lifecycle_bounds_fail_when_state_is_stale
  test_destroy_boundary_refuses_protected_target
  test_post_destroy_baseline_requires_exact_ids
  printf 'ok - proof lifecycle tests\n'
}

main "$@"
