# DigitalOcean exit candidates

Checked 2026-09-02 from Hangzhou China Telecom 5G. This shortlist supports the San Francisco-first decision in ADR 0003. It does not provide Tokyo evidence.

## Current order

| candidate | role | evidence | next test |
|---|---|---|---|
| `sfo2` | Primary San Francisco candidate | Paid exit-node run: 153 ms median, 0 percent loss in the clean short sample, 222 Mbit/s raw download, 20.5 Mbit/s raw upload | Intended tunnel on TCP/443, server CPU, and a clean 30-minute peak session |
| `sfo3` | Same-city replacement candidate | Free screen: 152 ms median, 178 ms p95, one lost packet out of 100 | Re-screen beside `sfo2`; rent only if replacement-prefix or capacity testing is needed |
| `tor1` | Geographic fallback | Free screen: 217 ms median, 233 ms p95, 0 percent loss | Keep behind both San Francisco regions unless peak screening reverses the order |
| `nyc3` | Secondary fallback | Free screen: 235 ms median, 257 ms p95, 0 percent loss | No paid test unless Toronto fails |

The region screen uses `<slug>.digitaloceanspaces.com`. These endpoints run on DigitalOcean's network and rank regional paths without renting. They may use different prefixes and transit than Droplets, and they cannot accept an upload test. A paid exit-node run remains necessary before promotion.

## Lower-priority measured regions

- `sgp1` is rejected for this access path. Its paid run produced only 3.96 Mbit/s upload with 3,369 retransmits.
- `lon1` had a 242 ms median but a 547 ms p95 and 1,056 ms maximum. Its tail is too unstable.
- `syd1`, `fra1`, `ams3`, and `blr1` were slower or less stable than the North American candidates.

## Unscreened current regions

The live DigitalOcean regions API also lists `atl1`, `ric1`, `mkc1`, and `mem1`. Their Spaces names resolve publicly, but they have not been screened from the bare China Telecom path. The screen wizard now includes them. `nyc1` and `nyc2` remain in the API but their matching Spaces names are NXDOMAIN, so the free method may skip them.

Do not spend another paid cycle merely because a region is available. Run the free screen during a valid 20:00 to 23:00 CST window first. A new region must beat `sfo2` on peak stability or provide a clear failover benefit before it earns a paid test.
