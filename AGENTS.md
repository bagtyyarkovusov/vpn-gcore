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

### Domain docs

Use the single-context layout with `CONTEXT.md` and `docs/adr/` at the repository root. See `docs/agents/domain.md`.
