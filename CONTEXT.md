# Japan VPN proof of concept

This context describes the people and network roles involved in proving a Japan internet exit for a small private pilot.

## Language

**Exit node**:
The Japan server that sends client traffic to the public internet.
_Avoid_: VPN server, proxy server

**Relay**:
An optional intermediary that forwards traffic to an exit node without becoming the public internet exit.
_Avoid_: Bridge, transit node

**Control plane**:
Software that manages users, nodes, and subscriptions but does not carry user traffic.
_Avoid_: Panel, backend

**Client app**:
The Android application that establishes the tunnel.
_Avoid_: VPN client, mobile client

**Tester**:
A person participating in the private proof of concept.
_Avoid_: User, customer
