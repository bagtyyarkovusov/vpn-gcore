# VPN Gcore

Public planning and engineering repository for a Japan VPN proof of concept.

The first milestone is to measure candidate Tokyo routes from the target mainland China network and validate one Xray-compatible deployment. Client branding and remote node management come after the network path is proven.

## Project workflow

- GitHub Issues hold research, decisions, experiments, and implementation work.
- [`CONTEXT.md`](CONTEXT.md) defines the project's agreed domain vocabulary.
- [`docs/adr/`](docs/adr/) records architectural decisions that are costly to reverse.
- [`docs/benchmark-protocol.md`](docs/benchmark-protocol.md) defines the route and tunnel test method.
- [`docs/research/tokyo-vps-candidates.md`](docs/research/tokyo-vps-candidates.md) tracks current providers and first-party test endpoints.
- [`scripts/do-route-wizard.sh`](scripts/do-route-wizard.sh) walks one create, measure, destroy cycle against a temporary DigitalOcean exit node.
- Public files must never contain server credentials, client UUIDs, private keys, subscription secrets, or administrative endpoints.

The project is currently in discovery. Follow the [proof-of-concept parent issue](https://github.com/bagtyyarkovusov/vpn-gcore/issues/1) for progress. Deployment instructions and compatibility guarantees have not been established.
