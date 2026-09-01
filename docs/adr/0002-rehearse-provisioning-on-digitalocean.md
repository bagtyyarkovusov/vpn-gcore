---
status: accepted
supersedes: none
amends: 0001-prove-the-route-before-product-work
---

# Rehearse provisioning on DigitalOcean, outside the Tokyo route gate

ADR 0001 gates product work behind a proven direct Tokyo route. That gate stands. This decision records a narrow, deliberate exception to its ordering: the project will provision short-lived exit nodes on DigitalOcean before the three route-screen days are complete, purely to rehearse tooling.

DigitalOcean operates no datacenter in Japan. Its only Asia-Pacific regions are `sgp1` Singapore, `blr1` Bangalore, and `syd1` Sydney, all confirmed available against the live regions API on 2026-09-02. A Droplet in any of them is therefore incapable of producing Tokyo route evidence, and its measurements must never be recorded against the route gate in issue #4.

What it can produce is everything the route gate does not cover: a working provisioning path, a minimum Xray-compatible server configuration, a v2rayNG connection, and the measurement automation that Stage 2 and Stage 3 of the benchmark protocol assume already exists. Rehearsing those against a disposable server is cheaper than discovering they are broken on the first real Tokyo candidate.

DigitalOcean also publishes no working first-party test endpoint. The former `speedtest-<region>.digitalocean.com` hosts no longer resolve on public DNS, so unlike Akamai, Vultr, Kamatera, and Gcore, its route cannot be screened before renting. Renting is the only way to measure it. That makes a create, measure, destroy cycle the only sound shape for this work, and it happens to bound the cost tightly: Droplets bill hourly, so a four-hour cycle on the recommended `s-2vcpu-2gb` plan costs about USD 0.11 against a USD 20 monthly ceiling.

Three constraints make the exception safe to grant. The account holds pre-existing Droplets belonging to unrelated projects, so `docs/agents/infrastructure-safety.md` applies without relaxation. The account's Droplet limit leaves exactly one free slot, so the experiment may hold at most one instance at a time and must return the slot when it finishes. And a powered-off Droplet still bills, so the cycle ends in destroy, never in stop.

`scripts/do-route-wizard.sh` implements the cycle and enforces all three constraints, including refusing to measure while a commercial VPN is intercepting the connection.
