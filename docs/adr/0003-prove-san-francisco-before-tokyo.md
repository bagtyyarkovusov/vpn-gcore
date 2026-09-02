---
status: accepted
amends: 0001-prove-the-route-before-product-work
---

# Prove San Francisco before Tokyo

San Francisco is now the first exit location for the proof of concept, while Tokyo is deferred as a later exit location. The proof-before-product rule from ADR 0001 still applies to the current location: `sfo2` must pass the intended tunnel test and valid peak-hour sessions before operator-authority, policy-agent, or custom tunnel-client work begins. The benchmark protocol still supplies the method and numerical gates, with its location gate changed to San Francisco, California, United States for this track. This changes the location and order in ADR 0001; it does not turn any DigitalOcean result into Tokyo evidence.

The choice follows a free DigitalOcean region screen and one paid raw-route run from Hangzhou China Telecom 5G. The `sfo2` exit node measured 153 ms median latency with no loss in the clean 100-packet sample, 222 Mbit/s raw download, and 20.5 Mbit/s raw upload off-peak. The longer stability run was contaminated by unrelated access-network outages and cannot support a stability claim. `sfo2` is the primary candidate, `sfo3` is the same-city replacement candidate, and `tor1` is the first geographically separate fallback.
