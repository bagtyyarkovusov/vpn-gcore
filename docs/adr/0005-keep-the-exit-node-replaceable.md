---
status: accepted
---

# Keep the exit node replaceable

The pilot node contains pinned Xray, dual firewalls, monitoring, and a small policy agent, but it is not the authority for testers, policy, usage history, profile delivery, or administrative records. Those remain encrypted off-node under an operator-only command-line authority. This boundary rejects the easier single-node panel design so a compromised or failed exit node can be rebuilt without recovering mutable business state from it.

The policy agent may keep a bounded local spool and the policy needed to operate, but Xray's management API remains loopback-only and no panel, database, Docker runtime, public metrics endpoint, or inbound management service belongs on the exit node.
