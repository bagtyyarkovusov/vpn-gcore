# Regional VPN proof of concept

This context describes the people, locations, and network roles involved in proving regional internet exits for a small private pilot. San Francisco is the current focus; Tokyo remains a planned location.

## Language

**Exit node**:
One server that sends client traffic to the public internet from an exit location.
_Avoid_: VPN server, proxy server

**Exit location**:
A city offered to testers as the apparent location of their public internet traffic. An exit location may use more than one exit node for capacity or replacement.
_Avoid_: Region, server, node

**Relay**:
An optional intermediary that forwards traffic to an exit node without becoming the public internet exit.
_Avoid_: Bridge, transit node

**Proof node**:
A temporary exit node used only to collect route, tunnel, and capacity evidence before pilot software is allowed.
_Avoid_: Test server, experiment Droplet

**Pilot node**:
The replaceable exit node admitted to carry tester traffic after the proof gate passes.
_Avoid_: Production server, permanent server

**Tunnel client**:
An approved iOS application that establishes the tester's tunnel to an exit node.
_Avoid_: Client app, VPN client

**Supported client build**:
One exact iOS, tunnel-client, and profile combination that has passed the project's compatibility tests.
_Avoid_: Supported app, supported iPhone

**Device identity**:
The credential assigned to one registered tester device. Two devices belonging to the same tester have different device identities.
_Avoid_: User credential, shared UUID

**Node identity**:
The cryptographic identity used by one exit node and referenced by tunnel-client profiles.
_Avoid_: Server key, node credential

**Control plane**:
Software that manages testers, nodes, and subscriptions without carrying tester traffic.
_Avoid_: Panel, backend

**Operator authority**:
The off-node source of truth for testers, device identities, policy, and administrative history.
_Avoid_: Control plane, database

**Policy agent**:
The replaceable node component that applies signed policy and exports usage without becoming the operator authority.
_Avoid_: Control plane, panel

**Usage batch**:
An append-only, bounded record of aggregate transfer counters exported by a policy agent.
_Avoid_: Traffic log, billing record

**Policy snapshot**:
A signed, versioned statement of the device identities and limits that a policy agent should apply.
_Avoid_: Server config, subscription

**Soft quota**:
A transfer allowance enforced after bounded accounting delay and unable to terminate every already-authenticated stream exactly at the limit.
_Avoid_: Hard cap, billing quota

**Valid route session**:
A benchmark session whose access-network controls remain healthy enough to attribute the result to the tested route.
_Avoid_: Successful test, completed run

**Cold replacement**:
An exit node created after a failure rather than kept running as a standby.
_Avoid_: Failover node, backup server

**Tester**:
A person participating in the private proof of concept.
_Avoid_: User, customer
