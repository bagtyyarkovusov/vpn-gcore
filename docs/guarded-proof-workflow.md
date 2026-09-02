# Guarded proof workflow

`scripts/do-route-wizard.sh` is the only approved path for a temporary
DigitalOcean proof node. It is a human-driven workflow: the operator must review
the exact name, region, size, image, tag, pinned Xray version, billing note, and
protected-baseline status before authorizing creation.

## Boundaries

- The proof lifecycle is limited to one tagged node, at most seven days, and at
  most USD 5. If the boundary is reached, stop measurement and use the guarded
  single-resource destroy path. The budget is enforced against the provider's
  own quoted hourly price, recorded into private state at selection time. A size
  with no recorded price fails closed rather than running unbounded.
- The compute budget does not model bandwidth. The iperf3 server is installed
  but left disabled, started only for the throughput transfers and stopped
  again, and the node runs a default-deny host firewall.
- The wizard checks the protected baseline before creation and checks it again
  after destruction by exact Droplet ID, not by count alone.
- A cloud mutation is allowed only after the wizard's explicit confirmation
  prompt. The human's answer is the only thing that sets the authorization flag;
  a call site that hardcodes it makes the gate decorative. Tests and dry-runs
  must not set that authorization.
- Once a Droplet exists, every exit path prints the exact single-resource
  destroy command, whatever ended the run.
- Uploading the experiment SSH key is also a cloud mutation. The wizard prompts
  separately before upload, records whether this lifecycle created the account
  key, and prompts to delete that key after the proof node is destroyed.
- A destroy action must target the recorded Droplet ID and pass committed
  lifecycle checks plus the private guard's ownership checks. The committed
  check verifies target ID, ownership tag, name, region, size, and the remaining
  protected baseline before deletion. Never widen the target to an account,
  region, or tag sweep.
- The guard's decision logic lives in `scripts/do-guard.sh`, under review and
  test like everything else. Only the protected baseline itself — the list of
  Droplet IDs — stays private, in a mode-600 file outside this repository.

## Evidence

Every measurement capture records the command line and its real exit code. A
failed probe marks the session invalid until the operator records a specific
reason. The wizard writes private raw captures, the private tunnel profile, and
a sanitized `manifest.json` under `/private/tmp`; publish only reviewed,
redacted summaries.

The proof node installs pinned Xray with VLESS, REALITY, XTLS Vision, RAW TCP,
and systemd supervision on TCP/443. Readiness captures include TCP/443 reachability,
Xray service status, Xray config validation, host firewall state, DNS state,
DigitalOcean firewall state, and server CPU, memory, and network counters around
throughput runs. The iperf3 runs measure the raw path to the Droplet, not
traffic through the Xray tunnel; they are not tunnel-throughput evidence, and
the route gate still needs a client-side measurement through the tunnel. The generated tunnel profile contains live secrets and must
never be pasted into GitHub or committed output.

The manifest is written once the result is recorded and rewritten after the
node is destroyed, so a completed run's manifest shows the destroyed state
rather than a still-live node. It records lifecycle state, timestamps, region,
size, image, hourly price, budget and duration limits, command outcomes, capture
checksums, tool versions, and any invalid-session reason. Capture *contents*
never enter it — only file names and checksums. The invalid-session reason is
operator-written free text, so IPv4 and IPv6 addresses are redacted from the
encoded manifest as a backstop. Exact Droplet IDs, Droplet names, live addresses, and
account identifiers remain only in private state and raw captures.

## Interruption Recovery

If the wizard finds an existing `DO_DROPLET_ID` in
`/private/tmp/vpn-gcore-do-run.env`, it reuses the recorded `DO_RUN_DIR`, checks
the original private state when present, and stops before any new create call.
Finish the recorded lifecycle first with the single-resource guarded destroy
command shown by the wizard, then rerun from a clean protected baseline.

If the recorded node cannot be verified as the exact project-owned lifecycle,
stop and reconcile by hand. Do not create a replacement and do not run a broader
cleanup.
