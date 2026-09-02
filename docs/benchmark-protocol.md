# San Francisco route benchmark protocol

## Purpose

Use this protocol to decide whether the `sfo2` San Francisco exit node is good enough for the private proof of concept. The primary test network is China Telecom 5G in Hangzhou. Results do not represent another carrier, access type, city, iOS version, or tunnel-client build.

The first round tests a direct route. Test a relay only after the direct candidates fail and the measurements show why.

## Safety and publication rules

Keep raw results in a private working location until they have been reviewed. Public results may name the provider, region, plan, server ASN, test date, and measured values. Do not publish credentials, UUIDs, subscription URLs, private keys, administrative endpoints, full client configurations, or an active exit node's public IP. Redact unrelated hop addresses if a trace exposes private network details.

## Candidate entry criteria

Before renting a server, record first-party evidence for:

- a San Francisco compute location;
- the current monthly price and any setup, traffic, or bandwidth charges;
- a provider-operated test IP, looking glass, or test file when available;
- the plan's traffic allowance, port speed, billing interval, and cancellation rules.

A provider's route name or marketing claim is not proof of route quality from China Telecom in Hangzhou. If a provider has no test endpoint, mark pre-rental route quality as unknown rather than guessing.

## Test controls

Keep these variables as stable as practical:

- Test from the same physical location and China Telecom SIM.
- Record whether the device reports 5G or LTE and capture signal strength when available.
- Disable other VPNs, private DNS overrides, downloads, cloud backups, and operating-system updates.
- Keep the test device stationary and use the same tethering method for every candidate.
- Record local time in China Standard Time, UTC+08:00.
- Run one off-peak session and one peak session between 20:00 and 23:00 on three separate days.
- Run candidates in alternating order when comparing them in the same session.

Mobile radio conditions can dominate a short test. Run continuous controls against a stable nearby target and the candidate throughout each session. A material control-path outage, unexplained access change, or inability to sustain the benchmark makes the route session invalid rather than a pass or failure.

## Stage 1: pre-rental route screening

Use only provider-operated test endpoints. For each candidate and session:

1. Send 100 ICMP echo requests and record minimum, median, average, 95th percentile, maximum, jitter, and packet loss.
2. Run a route trace with enough probes to identify persistent detours and loss patterns. Prefer both ICMP and TCP port 443 when the tool supports them.
3. Download the provider's test file three times. Record transferred bytes, elapsed time, and average throughput for each run.
4. Note unreachable probes and ICMP-only loss. Do not treat loss at an intermediate hop as end-to-end loss when later hops respond normally.

Shortlist candidates by measured peak-hour stability first, then latency, throughput, and price. A cheaper route that drops packets during the target usage window is not the better candidate.

## Stage 2: raw network tests after rental

Repeat the Stage 1 latency and route tests against the rented exit node. Also run:

- three download and three upload throughput tests with the same tool, endpoint, stream count, and duration;
- `iperf3` in both directions when a controlled peer is available;
- a 30-minute continuous latency test to expose bursts of loss or radio handovers;
- TCP connection tests on the port intended for the tunnel.

Record server CPU use during throughput tests. A saturated small VM can look like a bad route.

## Stage 3: tunnel validation

Install only the minimum pinned Xray server configuration needed for VLESS with REALITY, XTLS Vision, RAW transport, and TCP/443. Connect first with Shadowrocket and repeat the compatibility checks with Hiddify, then record:

1. whether the client connects and remains connected for 30 minutes;
2. the public IP country, region, and ASN without publishing the active IP;
3. three download and three upload throughput tests using the same method as the raw tests;
4. latency, jitter, and packet loss through the tunnel;
5. DNS resolver country and any DNS leak result;
6. reconnect behavior after airplane mode, Wi-Fi and cellular transitions, screen lock and wake, app force-quit, phone restart, and an Xray service restart;
7. server CPU and memory use during the run.

Record the exact iOS, Shadowrocket, Hiddify, and Xray versions. Do not install a policy agent, operator authority, web panel, subscription service, or custom client during this stage.

## Accepted decision gate

The proof passes only when all of the following are true:

- total recurring infrastructure cost is no more than USD 20 per month;
- the observed public exit is in San Francisco, California, United States;
- the tunnel completes one valid 30-minute peak-hour run on three separate days without an unexplained disconnect;
- end-to-end peak-hour packet loss is at most 2 percent in each accepted session;
- peak-hour median tunnel throughput is at least 20 Mbit/s downstream and 5 Mbit/s upstream;
- the tunnel does not expose the access network's DNS resolver;
- the tested client reconnects within 15 seconds after an airplane-mode or Wi-Fi/cellular transition and within 60 seconds after an Xray service restart;
- server CPU and memory are recorded for every accepted throughput and stability run;
- the access-network controls remain healthy enough for every accepted run to be a valid route session.

If `sfo2` fails, keep the failed results and diagnose whether the route, tunnel, access network, or exit node caused the failure. Test `sfo3` only through its own guarded decision. A relay remains a separate experiment. Do not silently loosen thresholds after seeing the outcome.

## Result template

Copy this section for each candidate. Use `unknown` when a field cannot be verified.

```md
# Candidate result: <provider and plan>

## Candidate

- Provider:
- Plan:
- Region:
- Billing interval:
- Recurring price in original currency:
- Approximate USD price and exchange-rate date:
- Included traffic and port speed:
- First-party product source:
- First-party test endpoint source:

## Test setup

- Date:
- Start time, CST:
- Session: off-peak | peak
- Test location: Hangzhou
- Access network: China Telecom 5G
- Device and operating system:
- Radio state and signal strength:
- Tethering method:
- Measurement tools and versions:
- Notes on local network conditions:

## Pre-rental or raw route

- Target type: provider test endpoint | rented exit node
- Ping min / median / average / p95 / max, ms:
- Jitter, ms:
- Packet loss, percent:
- Trace summary:
- Download runs, Mbit/s:
- Upload runs, Mbit/s:
- Continuous-test incidents:
- Server CPU during test, percent:

## Tunnel

- Protocol and transport, without secrets:
- Connected for 30 minutes: yes | no
- Disconnect count and reason:
- Exit country / region / ASN:
- Download runs, Mbit/s:
- Upload runs, Mbit/s:
- Latency / jitter / packet loss:
- DNS resolver country and leak result:
- Airplane-mode reconnect result:
- Wi-Fi / cellular transition result:
- Screen-lock / wake result:
- App force-quit / phone restart result:
- Xray restart result:
- Client and iOS versions:
- Server CPU and memory during test:

## Assessment

- Recurring budget gate: pass | fail | unknown
- San Francisco exit gate: pass | fail | unknown
- Stability gate: pass | fail | unknown
- Packet-loss gate: pass | fail | unknown
- Throughput gate: pass | fail | unknown
- DNS gate: pass | fail | unknown
- Overall: pass | fail | more data needed
- Evidence for the decision:
- Follow-up:
```
