# VPN Gcore

Public planning and engineering repository for a regional VPN proof of concept.

The current milestone is to validate San Francisco from the target mainland China network with an Xray-compatible deployment. Tokyo remains a planned exit location. Policy-agent, custom-client, and commercial work come after the current network path is proven.

## Project workflow

- GitHub Issues hold research, decisions, experiments, and implementation work.
- [`CONTEXT.md`](CONTEXT.md) defines the project's agreed domain vocabulary.
- [`docs/adr/`](docs/adr/) records architectural decisions that are costly to reverse.
- [`docs/benchmark-protocol.md`](docs/benchmark-protocol.md) defines the route and tunnel test method.
- [`docs/research/tokyo-vps-candidates.md`](docs/research/tokyo-vps-candidates.md) tracks current providers and first-party test endpoints.
- [`docs/research/digitalocean-exit-candidates.md`](docs/research/digitalocean-exit-candidates.md) ranks the current San Francisco and fallback candidates.
- [`scripts/do-route-wizard.sh`](scripts/do-route-wizard.sh) walks one create, measure, destroy cycle against a temporary DigitalOcean exit node.
- Public files must never contain server credentials, client UUIDs, private keys, subscription secrets, or administrative endpoints.

The project is currently in discovery. [San Francisco spec #9](https://github.com/bagtyyarkovusov/vpn-gcore/issues/9) is the current design and work index; the existing [Tokyo proof-of-concept issue](https://github.com/bagtyyarkovusov/vpn-gcore/issues/1) remains open but deferred. There is no live proof node, and accepting the design does not authorize cloud provisioning. Deployment instructions and compatibility guarantees have not been established.
