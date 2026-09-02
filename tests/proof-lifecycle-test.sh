#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/proof-lifecycle.sh"

# do-guard.sh announces itself and reads the baseline on load; point it at a
# fixture and keep its banner out of the test output.
DO_PROTECTED_IDS="$(mktemp)"
printf '100\n101\n' >"$DO_PROTECTED_IDS"
source "$ROOT/scripts/do-guard.sh" >/dev/null

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR" "$DO_PROTECTED_IDS"' EXIT

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

test_recovery_resumes_exact_owned_lifecycle() {
  local run="$TMPDIR/recovery-resume"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7 v26.6.1
  proof_record_created "$run" 555 vpn-gcore-exp-proof sfo2 s-2vcpu-2gb
  printf '10\n11\n' >"$run/protected-ids.txt"
  printf '{"droplet":{"id":555,"name":"vpn-gcore-exp-proof","region":{"slug":"sfo2"},"size_slug":"s-2vcpu-2gb","tags":["vpn-gcore-experiment"]}}\n' >"$run/live-droplet.json"

  proof_recovery_plan "$run/state.json" "$run/protected-ids.txt" "$run/live-droplet.json" >"$TMPDIR/resume.out" 2>&1 \
    || fail "exact owned lifecycle did not resume"
  assert_file_contains "$TMPDIR/resume.out" 'resume exact owned lifecycle 555'
}

test_recovery_marks_absent_droplet_for_destroyed_state() {
  local run="$TMPDIR/recovery-absent"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7 v26.6.1
  proof_record_created "$run" 555 vpn-gcore-exp-proof sfo2 s-2vcpu-2gb
  printf '10\n11\n' >"$run/protected-ids.txt"
  printf '{"droplet":null}\n' >"$run/live-droplet.json"

  proof_recovery_plan "$run/state.json" "$run/protected-ids.txt" "$run/live-droplet.json" >"$TMPDIR/absent.out" 2>&1 \
    || fail "absent Droplet recovery did not succeed"
  assert_file_contains "$TMPDIR/absent.out" 'mark lifecycle destroyed after baseline verification'
}

test_successful_lifecycle_reaches_destroyed_state() {
  local run="$TMPDIR/success"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7 v26.6.1
  assert_json_field "$run/state.json" "data['state']" "initialized"

  proof_record_created "$run" 555 vpn-gcore-exp-proof sfo2 s-2vcpu-2gb
  assert_json_field "$run/state.json" "data['state']" "created"

  proof_record_outcome "$run" "node-tcp443-connect" 0
  proof_record_outcome "$run" "node-readiness-services" 0

  printf '100\n101\n' >"$run/protected.txt"
  printf '{"droplets":[{"id":100},{"id":101},{"id":555,"name":"vpn-gcore-exp-proof","region":{"slug":"sfo2"},"size_slug":"s-2vcpu-2gb","tags":["vpn-gcore-experiment"]}]}\n' >"$run/live.json"
  proof_verify_destroy_boundary "$run/state.json" "$run/protected.txt" "$run/live.json" 555 \
    || fail "success path failed the destroy boundary"

  printf '{"droplets":[{"id":100},{"id":101}]}\n' >"$run/post-destroy.json"
  proof_verify_protected_baseline "$run/protected.txt" "$run/post-destroy.json" \
    || fail "success path failed post-destroy baseline verification"

  proof_record_destroyed "$run"
  proof_write_manifest "$run" ""

  assert_json_field "$run/manifest.json" "data['state']" "destroyed"
  assert_json_field "$run/manifest.json" "data['outcomes']['node-tcp443-connect']['passed']" "True"
  assert_json_field "$run/manifest.json" "'destroyed_at_utc' in data" "True"
  # a valid session is marked by an empty reason, never by an absent key
  assert_json_field "$run/manifest.json" "data['invalid_session_reason']" ""
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

test_wizard_bootstrap_enables_bbr_and_xray_buffers() {
  local wizard="$ROOT/scripts/do-route-wizard.sh"
  assert_file_contains "$wizard" 'net.core.default_qdisc=fq'
  assert_file_contains "$wizard" 'net.ipv4.tcp_congestion_control=bbr'
  assert_file_contains "$wizard" 'tc qdisc replace dev eth0 root fq'
  assert_file_contains "$wizard" '"policy":'
  assert_file_contains "$wizard" '"bufferSize": 4096'
}

test_wizard_x25519_parser_accepts_xray_26_key_labels() {
  local wizard="$ROOT/scripts/do-route-wizard.sh"
  assert_file_contains "$wizard" 'Private\[\[:space:\]\]\*\[Kk\]ey:'
  assert_file_contains "$wizard" 'Public\[\[:space:\]\]\*\[Kk\]ey:'
  ! grep -q "awk '/Private key:/ {print" "$wizard" \
    || fail "wizard still only parses old Private key label"
}

test_wizard_xray_config_is_readable_by_service_user() {
  local wizard="$ROOT/scripts/do-route-wizard.sh"
  assert_file_contains "$wizard" 'chown nobody:root /usr/local/etc/xray/config.json'
  assert_file_contains "$wizard" 'chmod 640 /usr/local/etc/xray/config.json'
  ! grep -q 'chmod 600 /usr/local/etc/xray/config.json' "$wizard" \
    || fail "wizard still makes xray config unreadable by the nobody service user"
}

test_wizard_remote_commands_do_not_consume_prompt_stdin() {
  local wizard="$ROOT/scripts/do-route-wizard.sh"
  ! grep -q 'run_measurement .*ssh -o ' "$wizard" \
    || fail "wizard has an ssh measurement without -n"
  ! grep -q 'run_measurement .*scp -o ' "$wizard" \
    || fail "wizard has an scp measurement without batch mode"
  assert_file_contains "$wizard" 'run_measurement "fetch-shadowrocket-profile"[[:space:]]+scp -B '
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

test_failed_state_update_leaves_previous_file_intact() {
  local run="$TMPDIR/json-guard"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7
  proof_record_created "$run" 555 vpn-gcore-exp-proof sfo2 s-2vcpu-2gb
  local before
  before=$(cat "$run/state.json")

  # An unparseable state file makes the update script fail. The old content must
  # survive: a truncated state.json strands a live Droplet, because every later
  # guard reads it and refuses to destroy.
  printf '{ broken' >"$run/state.json"

  set +e
  proof_record_outcome "$run" "node-ping-100" 0 2>/dev/null
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "a failed state update reported success"
  [[ "$(cat "$run/state.json")" == "{ broken" ]] \
    || fail "a failed state update overwrote state.json"

  # And the happy path still writes.
  printf '%s' "$before" >"$run/state.json"
  proof_record_outcome "$run" "node-ping-100" 0
  assert_json_field "$run/state.json" "data['outcomes']['node-ping-100']['passed']" "True"
}

test_failed_env_cleanup_leaves_previous_file_intact() {
  local env="$TMPDIR/guarded.env"
  printf 'DO_REGION=sfo2\nDO_DROPLET_ID=555\n' >"$env"

  # Shadow python3 with one that always fails, so the rewrite cannot succeed.
  local stub="$TMPDIR/failing-python"
  mkdir -p "$stub"
  printf '#!/bin/sh\nexit 1\n' >"$stub/python3"
  chmod +x "$stub/python3"

  set +e
  PATH="$stub:$PATH" proof_forget_env_keys "$env" DO_DROPLET_ID 2>/dev/null
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "a failed env cleanup reported success"
  assert_file_contains "$env" '^DO_DROPLET_ID=555$'
}

test_budget_guard_refuses_an_unpriceable_size() {
  local run="$TMPDIR/unpriced"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-99vcpu-999gb ubuntu-24-04-x64 5 7

  set +e
  proof_enforce_lifecycle_bounds "$run/state.json" >"$TMPDIR/unpriced.out" 2>&1
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "an unpriceable size passed the budget guard"
  assert_file_contains "$TMPDIR/unpriced.out" 'no hourly price recorded'
}

test_budget_guard_uses_the_recorded_provider_price() {
  local run="$TMPDIR/priced"
  mkdir -p "$run"
  # An unknown slug, but the provider quoted a price, so the budget is bounded.
  proof_init_state "$run" sfo2 s-99vcpu-999gb ubuntu-24-04-x64 5 7 v26.6.1 0.02679
  assert_json_field "$run/state.json" "data['price_hourly_usd']" "0.02679"
  proof_enforce_lifecycle_bounds "$run/state.json" \
    || fail "a provider-priced size failed the budget guard"

  # An absurd hourly price blows the USD 5 budget within the first second.
  proof_init_state "$run" sfo2 s-99vcpu-999gb ubuntu-24-04-x64 5 7 v26.6.1 99999
  sleep 1
  set +e
  proof_enforce_lifecycle_bounds "$run/state.json" >"$TMPDIR/overbudget.out" 2>&1
  local status=$?
  set -e
  [[ "$status" -ne 0 ]] || fail "an over-budget lifecycle passed the budget guard"
  assert_file_contains "$TMPDIR/overbudget.out" 'exceeds USD 5'
}

test_manifest_redacts_addresses_in_free_text_but_keeps_timestamps() {
  local run="$TMPDIR/address-redaction"
  mkdir -p "$run"
  proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7

  # invalid_session_reason is operator-written free text copied into the
  # manifest verbatim, which makes it the one field where an address can
  # realistically reach a publishable artifact. Capture *contents* never do —
  # only their names and checksums are recorded.
  proof_write_manifest "$run" "node 2604:a880:2:d0::1:b001 and 203.0.113.14 stopped answering"

  ! grep -qi '2604:a880' "$run/manifest.json" || fail "manifest leaked an IPv6 address"
  ! grep -q '203\.0\.113\.14' "$run/manifest.json" || fail "manifest leaked an IPv4 address"
  assert_file_contains "$run/manifest.json" '<redacted-ipv6>'
  assert_file_contains "$run/manifest.json" '<redacted-ipv4>'
  # Redaction must not eat the ISO timestamps the manifest exists to record.
  assert_file_contains "$run/manifest.json" '"created_at_utc": "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'
}

test_ownership_tag_follows_proof_tag() {
  local run="$TMPDIR/tag-override"
  mkdir -p "$run"
  PROOF_TAG="vpn-gcore-alt" proof_init_state "$run" sfo2 s-2vcpu-2gb ubuntu-24-04-x64 5 7
  assert_json_field "$run/state.json" "data['ownership_tag']" "vpn-gcore-alt"

  proof_record_created "$run" 555 vpn-gcore-exp-proof sfo2 s-2vcpu-2gb
  printf '100\n' >"$run/protected.txt"
  printf '{"droplets":[{"id":100},{"id":555,"name":"vpn-gcore-exp-proof","region":{"slug":"sfo2"},"size_slug":"s-2vcpu-2gb","tags":["vpn-gcore-alt"]}]}\n' >"$run/live.json"

  PROOF_TAG="vpn-gcore-alt" proof_verify_destroy_boundary \
    "$run/state.json" "$run/protected.txt" "$run/live.json" 555 \
    || fail "destroy boundary did not honour an overridden PROOF_TAG"
}

test_guard_payload_carries_the_experiment_tag() {
  local payload
  payload=$(do_create_droplet_payload proof-node sfo2 s-2vcpu-2gb ubuntu-24-04-x64 4242)
  printf '%s' "$payload" >"$TMPDIR/payload.json"
  assert_json_field "$TMPDIR/payload.json" "data['tags'][0]" "vpn-gcore-experiment"
  assert_json_field "$TMPDIR/payload.json" "data['backups']" "False"
  assert_json_field "$TMPDIR/payload.json" "data['name']" "proof-node"
}

test_guard_treats_baseline_ids_as_protected() {
  do_is_protected 100 || fail "a baseline id was not treated as protected"
  ! do_is_protected 555 || fail "a non-baseline id was treated as protected"
}

test_guard_protects_everything_without_a_baseline() {
  local empty="$TMPDIR/empty-baseline.txt"
  : >"$empty"
  # No baseline means no way to tell whose Droplet this is. Fail closed.
  DO_PROTECTED_IDS="$empty" do_is_protected 555 2>/dev/null \
    || fail "a missing baseline did not protect every Droplet"
}

test_wizard_never_hardcodes_cloud_authorization() {
  local wizard="$ROOT/scripts/do-route-wizard.sh"
  # Hardcoding the flag at a call site turns the mutation gate into a no-op.
  ! grep -q 'PROOF_CLOUD_AUTHORIZED=1 proof_require_mutation_authorized' "$wizard" \
    || fail "wizard hardcodes PROOF_CLOUD_AUTHORIZED at a mutation call site"
  grep -q 'trap proof_exit_reminder EXIT' "$wizard" \
    || fail "wizard has no exit reminder for a still-billing Droplet"
}

FAILURES=0
TEST_INDEX=0

# run_test NAME — each test runs in its own subshell so that a `fail` reports
# and moves on instead of hiding every test that follows it.
run_test() {
  TEST_INDEX=$((TEST_INDEX + 1))
  if ( trap - EXIT; set -e; "$1" ); then
    printf 'ok %d - %s\n' "$TEST_INDEX" "$1"
  else
    printf 'not ok %d - %s\n' "$TEST_INDEX" "$1"
    FAILURES=$((FAILURES + 1))
  fi
}

main() {
  local tests=(
  test_capture_preserves_failed_probe_status
  test_manifest_records_versions_checksums_statuses_and_redacts_ip
  test_baseline_mismatch_fails_closed
  test_recovery_refuses_wrong_ownership
  test_recovery_resumes_exact_owned_lifecycle
  test_recovery_marks_absent_droplet_for_destroyed_state
  test_successful_lifecycle_reaches_destroyed_state
  test_dry_run_blocks_cloud_mutation
  test_env_cleanup_removes_only_lifecycle_keys
  test_wizard_passes_pinned_xray_version_to_state
  test_wizard_bootstrap_enables_bbr_and_xray_buffers
  test_wizard_x25519_parser_accepts_xray_26_key_labels
  test_wizard_xray_config_is_readable_by_service_user
  test_wizard_remote_commands_do_not_consume_prompt_stdin
  test_pinned_xray_version_reaches_state_and_manifest
  test_manifest_omits_xray_version_when_unpinned
  test_destroy_boundary_accepts_exact_owned_target
  test_destroy_boundary_refuses_missing_ownership_tag
  test_destroy_boundary_refuses_identity_mismatch
  test_lifecycle_bounds_fail_when_state_is_stale
  test_destroy_boundary_refuses_protected_target
  test_post_destroy_baseline_requires_exact_ids
  test_failed_state_update_leaves_previous_file_intact
  test_failed_env_cleanup_leaves_previous_file_intact
  test_budget_guard_refuses_an_unpriceable_size
  test_budget_guard_uses_the_recorded_provider_price
  test_manifest_redacts_addresses_in_free_text_but_keeps_timestamps
  test_ownership_tag_follows_proof_tag
  test_guard_payload_carries_the_experiment_tag
  test_guard_treats_baseline_ids_as_protected
  test_guard_protects_everything_without_a_baseline
  test_wizard_never_hardcodes_cloud_authorization
  )

  printf '1..%d\n' "${#tests[@]}"
  local name
  for name in "${tests[@]}"; do
    run_test "$name"
  done

  if [[ "$FAILURES" -ne 0 ]]; then
    printf '\n%d of %d tests failed\n' "$FAILURES" "${#tests[@]}" >&2
    exit 1
  fi
  printf '\nall %d proof lifecycle tests passed\n' "${#tests[@]}"
}

main "$@"
