---
status: accepted
amends: 0001-prove-the-route-before-product-work
---

# Prove VLESS with REALITY on iOS before pilot work

The `sfo2` proof uses pinned Xray with VLESS, REALITY, XTLS Vision, RAW transport, and TCP/443. Shadowrocket is the primary iOS tunnel client and Hiddify is the independent compatibility check. This is one falsifiable tunnel candidate rather than a protocol collection: policy-agent, subscription, custom-client, and pilot work remain blocked until three valid peak-hour sessions pass the accepted route gate.

Ordinary unmanaged iPhones cannot supply Apple's managed Always On VPN guarantee. Support therefore attaches to exact tested iOS and tunnel-client builds, and the tester promise covers ordinary IPv4 internet and DNS traffic while the tested global profile is enabled and connected.
