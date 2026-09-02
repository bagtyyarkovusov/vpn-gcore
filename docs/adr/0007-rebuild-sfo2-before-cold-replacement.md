---
status: accepted
---

# Rebuild sfo2 before cold replacement

The pilot runs one `sfo2` node under the USD 20 recurring ceiling and keeps no warm standby. An assigned `sfo2` Reserved IPv4 is the tunnel endpoint, while tester traffic exits through the Droplet's native address. Ordinary non-security failures first trigger repair and a clean `sfo2` rebuild that preserves the uncompromised node identity and profiles.

The operator moves to a cold `sfo3` replacement when `sfo2` is unavailable, its address or prefix appears blocked, or an `sfo2` rebuild cannot restore service within two hours of the four-hour support-window target. `sfo3` cannot receive the `sfo2` Reserved IP, so it requires new route evidence, node identity, and profiles. `tor1` remains a later geographic fallback rather than automatic failover.
