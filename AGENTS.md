## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues for `bagtyyarkovusov/vpn-gcore`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the five default triage labels. See `docs/agents/triage-labels.md`.

### Infrastructure safety

Never delete or modify cloud resources this project did not create. See
`docs/agents/infrastructure-safety.md`.

Provision temporary exit nodes only through `scripts/do-route-wizard.sh`, which
verifies the protected baseline, tags what it creates, and destroys it again.

### San Francisco proof and pilot

Before changing the San Francisco tunnel, iOS compatibility, benchmark gate,
pilot limits, recovery policy, or provisioning lifecycle, read `CONTEXT.md`,
`docs/benchmark-protocol.md`, and ADRs 0003 through 0009. The accepted route
gate blocks policy-agent and pilot work until `sfo2` passes.

### Domain docs

Use the single-context layout with `CONTEXT.md` and `docs/adr/` at the repository root. See `docs/agents/domain.md`.
