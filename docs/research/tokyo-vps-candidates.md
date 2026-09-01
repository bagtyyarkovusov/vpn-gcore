# Tokyo VPS candidates for a Japan VPN proof of concept

Checked 2026-09-02. This is a purchasing and test shortlist for a proof of concept run from Hangzhou on China Telecom 5G. The infrastructure ceiling is about USD 20 per month.

The useful first step is to test Akamai, Vultr, Kamatera, and Gcore from the actual 5G connection before buying anything. Each publishes a Tokyo test service. None of the first-party material establishes how a newly assigned VM address will route to China Telecom, especially during the evening busy period. Provider marketing about a global network is not evidence of that route.

## Shortlist

| Provider | Small Tokyo option | Traffic and billing | First-party Tokyo test | Assessment |
|---|---|---|---|---|
| Akamai Cloud, formerly Linode | Nanode: 1 vCPU, 1 GB RAM, 25 GB SSD, 1 TB transfer, USD 5/month or USD 0.0075/hour | Inbound is free. Tokyo outbound overage is USD 0.005/GB. Powered-off instances continue to bill; usage is rounded up to the hour and capped at the monthly price. The included allowance is prorated and pooled at account level. | [Tokyo 3 speed test](https://jp-tyo-3.speedtest.linode.com/) and [100 MB file](https://jp-tyo-3.speedtest.linode.com/100MB-jp-tyo-3.bin); [official test directory](https://www.akamai.com/cloud/speed-test) | Best first paid trial. Low entry price, low overage, and a test file in the current Tokyo region. |
| Vultr | Regular Cloud Compute: 1 vCPU, 1 GB RAM, 25 GB SSD, 1 TB transfer, USD 5/month or USD 0.007/hour | Only outbound transfer counts. Overage is USD 0.01/GB. Allowance accrues hourly. A stopped instance bills until destroyed; hourly billing is capped at 672 hours in a month. | [Tokyo looking glass](https://hnd-jp-ping.vultr.com/), test IPv4 `108.61.201.151`, plus 100 MB and 1 GB files on that page | Best parallel comparison with Akamai. It provides an IP, route tools, and download files. |
| Kamatera | Basic: 1 shared/availability vCPU, 1 GB RAM, 20 GB NVMe, USD 4/month. Plus: 1 vCPU, 2 GB RAM, 20 GB NVMe, USD 6/month. | The current Tokyo FAQ limit is 1 TB total bidirectional traffic per month, despite the product page saying 5 TB. Overage is USD 0.01/GB. A monthly server is prepaid and still costs the full month if canceled after the first day. Hourly plans charge traffic separately and retain small disk/IP charges while powered off. | [Tokyo browser speed test](https://as-ty-speedtest.kamatera.com/) from the [official data-center page](https://www.kamatera.com/data-centers/) | Cheap, but the traffic wording and monthly cancellation rule need care. Test the endpoint before considering it. |
| Gcore | Tokyo promotion: VM Starter, 1 vCPU and 2 GB RAM, USD 8.70/month. The live pricing page also lists lower-cost Basic and sub-USD 20 Standard compute in Tokyo. | The promotion states free egress, free DDoS protection, a 99.9% SLA, and cancel-anytime service. The general VM page says egress is free and prices vary by location and exclude VAT. Confirm disk, public IPv4, tax, and the final recurring total in checkout because the promotion summary does not itemize all components. | [Speed test](https://speedtest.gcore.com/), [looking glass](https://lg.gcore.com/), and [looking-glass instructions](https://gcore.com/blog/how-to-check-connectivity-to-our-servers-with-looking-glass) with a Tokyo router | Gcore is a valid candidate on current first-party evidence. Its advertised Tokyo VM is comfortably under the ceiling, but checkout must confirm the complete VM price. |
| AWS Lightsail | Linux with public IPv4: 0.5 GB RAM, 20 GB SSD, 1 TB transfer for USD 5/month; 1 GB/40 GB/2 TB for USD 7; 2 GB/60 GB/3 TB for USD 12 | Hourly charges are capped at the bundle's monthly price. Inbound and outbound use the allowance, though only excess outbound is billed. Tokyo excess outbound is USD 0.14/GB. | No AWS-owned public Tokyo looking glass, test IP, or test file was found. | Predictable bundle and a good paid fallback, but the high overage and lack of a free route test put it behind Akamai and Vultr. |
| ConoHa VPS | 2 vCPU, 1 GB RAM, 100 GB SSD: JPY 1,065 monthly cap or JPY 1.9/hour | The current specification says transfer is unmetered at no extra charge, with a shared 100 Mbps Internet port, one IPv4 address, and IPv6 addresses. Prices are fixed in yen; card conversion and any applicable tax should be checked at purchase. | No provider-owned public Tokyo test endpoint was found. | Attractive local-market price and hourly cap, but it needs a paid instance to test the route. |
| Sakura VPS | Tokyo 1 GB: 2 vCPU, 1 GB RAM, 50 GB SSD, JPY 990/month. The published annual effective rate is JPY 908/month. | Shared 100 Mbps connection, one IPv4 address, IPv6, and unmetered traffic. The pre-contract notice specifies a three-month minimum term. | No provider-owned public Tokyo test endpoint was found. | Technically suitable, but the minimum term makes it a poor short proof-of-concept choice. |
| WebARENA Indigo | 1 vCPU, 1 GB RAM, 20 GB disk, 100 Mbps, IPv4 and IPv6: JPY 0.70/hour with a JPY 449 monthly cap | Traffic is advertised as unmetered, but the operating guide gives the 1 GB plan a 20 GB/day guideline and permits restrictions when load harms the service. Stopped instances bill until deleted. Any monthly charge has a JPY 55 minimum. Credit card only. | No provider-owned public Tokyo test endpoint was found. | Conditional. Since 2026-06-04, overseas access to its contract management and control panel is blocked unless support approves and allowlists an overseas global source IP. That is awkward on mobile access and should be resolved before purchase. |
| Oracle Cloud Infrastructure | Tokyo region `ap-tokyo-1`. Always Free Ampere capacity may fit a small proof of concept; paid A1 compute can also fit the ceiling. | Free capacity is not guaranteed and idle Always Free instances can be reclaimed. Paid A1 is USD 0.0100 per OCPU-hour plus USD 0.0015 per GB-hour, so 1 OCPU and 2 GB is about USD 9.67 for 744 hours before any chargeable storage. Stopping through OCI pauses standard compute billing. The first 10 TB/month outbound is free in Japan/APAC, then USD 0.025/GB. | No Oracle-owned public Tokyo looking glass, test IP, or test file was found. | Viable only if the console shows capacity and a complete under-budget configuration. Less predictable than the fixed bundles above. |

## Evidence and caveats by provider

### Akamai Cloud

The [official APAC pricing page](https://www.akamai.com/cloud/pricing/asia-pacific) identifies Tokyo and publishes the USD 5 Nanode and USD 12 Shared 2 GB plans. The public [regions API](https://api.linode.com/v4/regions?page_size=500) identifies `jp-tyo-3` as Tokyo, Japan, and the [types API](https://api.linode.com/v4/linode/types?page_size=500) publishes the machine resources and prices.

[Billing documentation](https://techdocs.akamai.com/cloud-computing/docs/understanding-how-billing-works) confirms hourly rounding, the monthly cap, and continued billing while powered off. [Network transfer documentation](https://techdocs.akamai.com/cloud-computing/docs/network-transfer-usage-and-costs) covers free inbound transfer, prorated and pooled allowance, and Tokyo overage.

The speed-test host can establish reachability and rough download behavior from the 5G connection. It cannot establish the route or performance of a later VM address.

### Vultr

The public [regions API](https://api.vultr.com/v2/regions?per_page=500) identifies `nrt` as Tokyo, Japan. The [plans API](https://api.vultr.com/v2/plans?type=vc2&per_page=500) publishes current Regular Cloud Compute prices, resources, and Tokyo availability.

Vultr documents [outbound-only bandwidth accounting](https://docs.vultr.com/support/platform/billing/how-is-bandwidth-usage-calculated), the [USD 0.01/GB overage](https://docs.vultr.com/support/platform/billing/what-is-the-bandwidth-overage-rate), and [continued billing until an instance is destroyed](https://docs.vultr.com/support/platform/billing/how-am-i-billed-for-my-servers). The official looking-glass page provides ping, MTR, traceroute, and download tests.

### Kamatera

The [Japan VPS page](https://www.kamatera.com/cloud-vps/japan-vps-hosting/) publishes the Tokyo bundles. Its 5 TB statement conflicts with Kamatera's current [monthly transfer-limit FAQ](https://www.kamatera.com/faq/answer/what-are-the-limits-on-internet-data-on-monthly-server-plans/), which explicitly assigns Tokyo a 1 TB bidirectional limit. For budgeting, use the narrower FAQ limit. Kamatera separately documents [monthly overage](https://www.kamatera.com/faq/answer/will-i-ever-be-charged-extra-for-internet-traffic-on-a-monthly-server-plan/), [hourly transfer charges](https://www.kamatera.com/faq/answer/what-are-the-traffic-data-transfer-rates-for-hourly-billed-servers/), [monthly and hourly billing](https://www.kamatera.com/faq/answer/how-does-billing-work/), [powered-off charges](https://www.kamatera.com/faq/answer/will-i-be-charged-for-my-hourly-server-even-when-its-powered-off/), and the [included first public IP](https://www.kamatera.com/faq/answer/how-many-ip-addresses-can-i-add-to-my-server/).

The official Tokyo endpoint is a browser speed test, not a downloadable file or looking glass. It is still useful for a first pass from the exact handset or tethered laptop that will use the VPN.

### Gcore

The current [Tokyo cloud promotion](https://gcore.com/go/tokyo-cloud-promotion) is sufficient first-party evidence for an affordable Tokyo VM. The [live cloud pricing page](https://gcore.com/pricing/cloud) also exposes Tokyo as a selectable location, while the [VM product page](https://gcore.com/cloud/virtual-machines) documents free egress and active-instance billing.

Gcore's looking glass runs probes from a selected Gcore router toward a target. A Tokyo-to-client probe is the reverse direction and may not follow the client-to-Tokyo path. It also requires exposing the client's current public IP to that test. Use it only if that is acceptable, and do not save or publish the result with the address intact.

### AWS Lightsail

The [bundle table](https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-bundles.html) publishes Linux public-IPv4 prices and resources. AWS added Lightsail to Tokyo in [June 2026](https://aws.amazon.com/about-aws/whats-new/2026/06/amazon-lightsail-aws-regions/). The [Lightsail transfer documentation](https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-faq-data-transfer-allowance.html) describes allowance accounting, and the [Lightsail FAQ](https://aws.amazon.com/lightsail/faq/) publishes the Tokyo overage rate.

This is a paid test. A short-lived instance should cost only its hourly use, but it must be deleted after the experiment rather than merely stopped.

### ConoHa, Sakura, and WebARENA

ConoHa publishes its [current price table](https://vps.conoha.jp/pricing/), [network and address specification](https://vps.conoha.jp/pricing/#spec), and a current support article that identifies the [Tokyo region](https://support.conoha.jp/v/dbnetwork/).

Sakura's [Tokyo price and specification page](https://vps.sakura.ad.jp/specification/) also publishes its application conditions, including the minimum term.

WebARENA publishes the [Indigo price](https://web.arena.ne.jp/indigo/price/), [fee rules](https://web.arena.ne.jp/indigo/price/fee.html), [service specification](https://web.arena.ne.jp/indigo/spec/), [traffic guideline](https://web.arena.ne.jp/indigo/spec/guide.html), and [Tokyo-only location](https://web.arena.ne.jp/indigopro/merit/diff_indigo.html). Its [overseas access notice](https://web.arena.ne.jp/news/2026/0604.html) explains the control-panel restriction and the support exception.

### Oracle Cloud Infrastructure

Oracle's [region list](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm) identifies Tokyo. The [Always Free guide](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm) documents capacity limits and idle-instance reclamation. Paid A1 rates come from Oracle's [global price list](https://www.oracle.com/apac/a/ocom/docs/corporate/pricing/oracle-paas-and-iaas-global-price-list.pdf); [stopped-instance billing](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/resource-billing-stopped-instances.htm) is documented separately.

## What the sources cannot verify

The first-party pages and endpoints do not answer several questions that matter more than the advertised VM size:

- The forward and return route between the exact China Telecom 5G attachment in Hangzhou and the assigned VM prefix.
- Evening packet loss, jitter, congestion, or throttling on that route.
- Whether the provider's test host and the purchased VM use the same network prefix, transit, or peering.
- UDP and VPN-protocol behavior through the mobile carrier, CGNAT, and the provider firewall.
- Shared-CPU contention on the selected low-cost plan.
- Account approval, stock, payment acceptance, tax, card conversion, and public-IPv4 availability at checkout.
- Whether the planned VPN use complies with the selected provider's current terms and local requirements. This should be checked before deployment.

## Test sequence from Hangzhou China Telecom 5G

Follow the controls and result format in [`docs/benchmark-protocol.md`](../benchmark-protocol.md).

1. Test on the actual 5G connection with any existing VPN disabled. Run one off-peak session and one 20:00-23:00 China Standard Time session on three separate days.
2. Test the Akamai Tokyo 3 and Vultr Tokyo files. Use Kamatera's browser test. Use Gcore's Tokyo speed test and, only if acceptable, its reverse-direction looking glass.
3. Record latency median, p95 latency, packet loss, jitter, download throughput, and route changes. Redact the client public IP and any account identifiers before saving results.
4. Provision one suitable IPv4 Linux instance from the strongest candidate. Test the assigned address before installing the VPN because a public test host is only a screening signal.
5. Run the raw-route and tunnel stages in the benchmark protocol. Start with its 30-minute peak-hour stability gate.
6. Delete a failed instance promptly. Stopping is not enough at Akamai, Vultr, Kamatera, Lightsail, or WebARENA.

Example non-destructive probes from a tethered macOS or Linux client:

```sh
ping -c 100 108.61.201.151
mtr -4 -rwzc 100 108.61.201.151
curl -4 -L -o /dev/null -sS \
  -w 'code=%{http_code} time=%{time_total}s speed=%{speed_download}B/s\n' \
  https://jp-tyo-3.speedtest.linode.com/100MB-jp-tyo-3.bin
```

These probes are useful for comparison, not proof. The purchase decision should follow the test from the real mobile connection, not the lowest published price.

## Checked and excluded

- [DigitalOcean](https://docs.digitalocean.com/platform/regional-availability/) does not currently list a Japan compute region. Confirmed against the live regions API on 2026-09-02: its only Asia-Pacific regions are `sgp1` Singapore, `blr1` Bangalore, and `syd1` Sydney. It also publishes no working test endpoint, because the former `speedtest-<region>.digitalocean.com` hosts no longer resolve on public DNS, so its route cannot be screened before renting. It is excluded as a Tokyo candidate and used only as a disposable rehearsal target for provisioning and measurement tooling, per [ADR 0002](../adr/0002-rehearse-provisioning-on-digitalocean.md).
- [UpCloud](https://upcloud.com/docs/getting-started/locations/) does not currently list a Japan or Tokyo cloud location; its published APAC locations are Singapore and Sydney.
