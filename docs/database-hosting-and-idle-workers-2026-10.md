# PostgreSQL hosting and idle-worker cost guide

Research date: 3 October 2026 UTC. Proposal, not a deployed or benchmarked architecture. All prices below are USD before taxes. No server, subscription or migration has been purchased by this research.

## Visual cost explorer

The HTML edition includes a cost bar chart, an awake-hours break-even graph and adjustable assumptions. These are infrastructure scenarios, not measured performance equivalents. The table below remains the readable source when scripts are disabled.

<!-- hosting-cost-explorer -->

At 20 GB and 0.5 Neon CU, European Hetzner's $12.59 crosses Neon's bill at about **105 awake hours/month** (3.5 hours/day in a 30-day model). US Hetzner's $45.59 crosses it at about **728 hours/month**, almost continuously awake. At 1 Neon CU, the US crossover is about **364 hours/month**. This is why CPX21 is not automatically cheaper than a sleeping Neon database.

Against our $25 Railway resource example, US CPX21 at $45.59 is more expensive. Railway can exceed it as RAM/CPU/storage usage increases: at 20 GB storage and 0.1 average vCPU, the arithmetic crosses near 4.06 GB average RAM. These are price intersections, not claims of equal capacity or measured workloads.

## Comparison matrix

| Decision | Railway PostgreSQL | Neon Launch | AWS RDS PostgreSQL | Hetzner self-managed PostgreSQL |
| --- | --- | --- | --- | --- |
| Cost predictability | Metered RAM/CPU/disk; workspace minimum | Depends on awake compute and storage | Selected instance/storage predictable; extras vary | Selected VM has monthly cap; extras vary |
| Idle savings | CPU may fall; resident RAM/disk still charged | Can suspend compute when genuinely idle | Ordinary instance keeps billing while running | VM keeps billing even when powered off |
| Who administers PostgreSQL? | Application operator manages database lifecycle; platform runs containers/volumes | Provider manages database infrastructure; app still owns schema/access | AWS manages database infrastructure; app configures operation/access | We administer OS, PostgreSQL, pgvector and recovery |
| Storage growth | Expand volume within plan limits; usage billed | Database storage grows and is billed | Provisioned storage; optional configured autoscaling | Finite VM disk; expand/migrate or add charged storage |
| Recovery requirement | Configure and test backup of DB plus originals | Configure restore history plus independent backups/originals | Configure backup/PITR plus originals; test restore | Build and test DB-aware off-server backup; VM snapshots alone insufficient |
| Single-instance failure | No automatic database HA assumed | Provider-managed design; check selected plan/SLA | Table prices are Single-AZ, not Multi-AZ | One VM has no automatic PostgreSQL failover |
| Location issue | Prefer same region/private app network | Match application region | Cross-provider VPC/network design if app remains elsewhere | Cheap CX quote is Europe; US plans cost more; measure latency |
| Polling-fix benefit | Fewer queries/CPU; not zero idle bill | Enables actual compute sleep if other clients permit | Less load; not automatic instance cost reduction | Less load/more headroom; unchanged base VM price |
| Best reason to choose | Existing topology and simpler incident recovery | Managed operations with intermittent traffic | AWS requirements and managed recovery options | Predictable low base price with accepted operational ownership |

## What fixed cost does—and does not—mean

Hetzner caps the charge for the chosen VM at its published monthly price. It does not charge more VM rent because PostgreSQL runs more queries. The machine still has finite CPU, RAM and disk: load can slow it down or exhaust capacity, requiring an intentional upgrade. Independent backup storage, extra volumes/snapshots/IPs, traffic beyond the allowance and additional servers can add charges. Provider prices can also change; the June 2026 revision is a concrete example.

For European CX33, $12.59 here already includes one IPv4 and the 20% server-backup option, **not** independent PostgreSQL backups, application hosting, tax or operational labor. Billing alerts do not impose a hard spending cap. Keep disk, CPU, memory and traffic monitoring even on a fixed-price VM. [Hetzner billing terms](https://docs.hetzner.com/cloud/billing/faq/).

## Recommendation

For an intermittently used knowledge application, compare **Neon with workers that can sleep** against **a self-managed Hetzner server**. Choose Railway when staying with the existing deployment and operational simplicity matters more than a modest possible saving. RDS becomes more attractive when AWS networking, managed recovery and availability requirements justify its larger operational footprint.

Hetzner can be the lowest predictable infrastructure bill, particularly in Europe. It transfers database administration to the application operator. Neon reduces that maintenance responsibility, but continuous application traffic can erase its idle-compute savings. There is no unconditional cheapest provider.

For a disk-full production incident, recover the current data first. Do not confuse choosing a future host with having a verified export available for migration. An existing volume expansion can be the shortest recovery route even if the database moves later.

## Monthly comparison

Model: one production PostgreSQL database, approximately 20 GB billable database storage where charged separately, 730 hours/month for continuously running resources. The hardware and performance are **not equivalent** across rows. These are calculations and planning allowances, not invoices, capacity tests or service-level guarantees.

| Option | Calculation / assumption | Database infrastructure per month |
| --- | --- | ---: |
| Railway | 2 GB average RAM + 0.1 average vCPU + 20 GB used volume | $25.00; practical provisional budget $25–35 |
| Neon Launch, light use | 0.5 CU × 60 awake hours × $0.106 + 20 GB × $0.35 | $10.18 |
| Neon Launch, moderate awake time | 0.5 CU × 240 awake hours × $0.106 + storage | $19.72 |
| Neon Launch, continuously awake | 0.5–1 CU × 730 hours + storage | $45.69–84.38 |
| RDS PostgreSQL, Oregon, Single-AZ small | `db.t4g.small` at $0.032/hour + 20 GB gp3 at $0.115 | $25.66 before extras; fit unproven |
| RDS PostgreSQL, Oregon, Single-AZ medium | `db.t4g.medium` at $0.065/hour + storage | $49.75 before extras |
| Hetzner Europe, CX33 | $9.99 server + $2.00 server backups + $0.60 IPv4 | **$12.59**, plus independent database backup |
| Hetzner US, CPX21 price illustration | $37.49 server + $7.50 server backups + $0.60 IPv4 | **$45.59**, plus independent database backup |

For an illustrative production total, add a separately stated **$10–20 application/operations allowance** to each database figure. That allowance has not been measured for a particular app. European Hetzner plus this allowance is about **$23–33**, before independent backup storage and operator time; sleeping Neon about **$20–40**; Railway about **$35–55**; medium RDS about **$60–70 before AWS extras**. Do not include an imaginary saving from moving the application too: that is a separate topology and benchmark.

Staging, AI inference and embedding API charges, taxes, excess traffic, migration overlap and human maintenance are excluded. Historical retention, write volume and recovery objectives determine independent backup costs; avoid quoting a fixed backup price without them. A one-off import or reindex may keep compute awake much longer than a normal month.

### Railway: metered resources, with a minimum

Published memory is $10/GB-month, CPU $20/vCPU-month and used-volume storage $0.15/GB-month. Hobby's $5 and Pro's $20 workspace minimum include usage. Do not add the minimum again to the same resource charge. The 5 GB Hobby volume ceiling, rather than PostgreSQL itself, can necessitate a plan change. Ordinary PostgreSQL remains running and consumes memory while idle. Sources: [plans](https://docs.railway.com/pricing/plans), [billing](https://docs.railway.com/pricing/understanding-your-bill), [volume limits](https://docs.railway.com/volumes/reference).

### Neon: awake time must be demonstrated

Launch compute is $0.106/CU-hour, storage $0.35/GB-month; restore-history storage is separately $0.20/GB-month when applicable. Five-minute auto-suspend only helps when actual queries/connections and provider behavior permit it. Storage still costs money while compute sleeps. Higher working-set demand can raise required compute. Sources: [pricing](https://neon.com/pricing), [compute lifecycle](https://neon.com/docs/manage/endpoints/).

### AWS: distinguish RDS from Aurora Serverless

RDS examples use the [official Oregon price list](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonRDS/current/us-west-2/index.json), published 1 October 2026, and [PostgreSQL pricing](https://aws.amazon.com/rds/postgresql/pricing/). Ordinary RDS charges for running instance hours and provisioned storage. Burst CPU, cross-provider networking and excess backups can add cost; Multi-AZ is not included here. Aurora Serverless v2 can pause at zero on eligible versions, but has different capacity units and storage/I/O charges. It is not the $0.06 old serverless rate: standard v2 Oregon capacity is $0.12/ACU-hour. See [Aurora pause conditions](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2-auto-pause.html).

### Hetzner: own the server operations

CX33 provides 4 shared vCPUs, 8 GB RAM and 80 GB local NVMe. It is a virtual server with administrator control, not a dedicated physical machine or a managed PostgreSQL service. Its disk also houses the operating system, logs and temporary work. The monthly server cap is predictable; extra services and traffic can still add charges, and powering it off does not delete its bill. Sources: [specifications and availability](https://www.hetzner.com/cloud/cost-optimized/), [billing](https://docs.hetzner.com/cloud/billing/faq/).

The current published Europe CX33 price is $9.99 excluding IPv4; US CPX21 is $37.49. These are different plans, not claims of equivalent hardware. Use current regional prices rather than old $4–8 advertisements. [June 2026 price adjustment](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/). IPv4 adds $0.60/month; server backups add 20% of server cost for seven slots. [IP pricing](https://docs.hetzner.com/cloud/servers/primary-ips/overview/), [backup billing](https://docs.hetzner.com/cloud/billing/faq/).

**Availability caveat:** the public cost-optimized page returned CX33 as unavailable during this research. This may reflect capacity or the page's dynamic state; no authenticated regional stock check or reservation was made. Treat $12.59 as a conditional quote, not an immediately procurable server. The low-price CX offering is European; do not apply its price to a US deployment.

A Railway application talking to a European database may incur extra latency on every database round trip. Measure the existing app region, candidate endpoint latency and representative multi-query requests before choosing a location. Provider-private networks do not automatically connect across companies. Design TLS with certificate verification, least-privilege database roles and a restricted network path; stable egress or a supported tunnel may add cost/complexity. Do not open PostgreSQL to every address merely to make a cheap comparison work.

The operator owns OS/PostgreSQL/pgvector updates, resource limits, disk/WAL alerts, access control, backup delivery and restore drills. A single VM has no automatic PostgreSQL failover. Agents can implement and maintain scripts, but are not an unattended operations service unless scheduled monitoring and an accountable responder actually exist.

Hetzner server snapshots/backups do **not** cover attached block volumes and are not a substitute for tested database-aware recovery or independent original-file backups. Keep a separate off-provider database/source backup; add WAL archiving only when a defined PITR objective requires and tests it. [Backup scope](https://docs.hetzner.com/cloud/servers/backups-snapshots/overview/).

## Storage: source bytes are not database capacity

Knowledge databases often store originals, extracted text, immutable versions, overlapping passages, vectors and multiple indexes. PostgreSQL additionally needs WAL, temporary/index-build space and filesystem headroom. Compressed dump size is not live disk demand. Original files may live on a different volume entirely.

An anonymized workload examined for this research had approximately 111 MB of new prepared uploads. A 512-character window with 64-character overlap projected 240,614 passages. At 1,536 dimensions, vectors alone occupy about 1.48 GB before passage text, indexes, WAL and the older corpus. This is a projection, not a measured index size. [pgvector storage formula](https://github.com/pgvector/pgvector/blob/master/README.md?plain=1).

Before bulk imports, measure database/table/index sizes, project chunk/vector growth, budget transient indexing/WAL peaks and check free disk. Preserve source archives while benchmarking a canonical retrieval representation and larger structure-aware passages. Do not silently delete provenance or break pinned citations to reduce size. Batching embedding requests can speed ingestion but does not itself reduce vector storage.

## Polling changes and their real savings

Use the [durable queue with idle workers recipe](../patterns/go/durable-index-jobs-with-idle-workers.md). A durable job row is the truth; an in-memory wake signal is a latency optimization. Wake only after the enqueue commits. Reconcile on startup and on a bounded slow timer so a crash or missed signal cannot lose work. Preserve concurrent claims, delayed retries, lease expiry and tenant boundaries.

Do not promise zero idle compute with periodic reconciliation. With a five-minute suspend delay:

| Empty-queue reconciliation | Approximate baseline awake time from checks alone | 0.5 CU compute + 20 GB storage |
| --- | ---: | ---: |
| Every 15 minutes | 8 hours/day; 240 hours in 30 days | $19.72/month |
| Every 60 minutes | 2 hours/day; 60 hours in 30 days | $10.18/month |
| Every 2 seconds | Continuously awake | $45.69/month using 730 hours |

These estimates assume short checks and successful suspend; user traffic, backups and actual jobs add time or overlap existing awake windows. Avoid a five-minute sweep on a five-minute suspend service: it can prevent sleep entirely. A slower safety sweep saves money but increases worst-case recovery delay after a missed wake. A 15-minute sweep is the initial proposed reliability setting; 60 minutes is an optional trade-off, not an approved default.

LISTEN/NOTIFY is useful for some always-on PostgreSQL deployments, but notifications are not durable work. It also introduces a persistent connection whose compatibility with actual provider suspension must be verified. Do not assume replacing SQL polling with LISTEN guarantees sleep. [PostgreSQL notification semantics](https://www.postgresql.org/docs/current/sql-notify.html).

Inspect the entire system: connection pools, readiness probes, uptime checks, scheduled backups, trash maintenance, front-end refresh and integrating agents. Provider metrics and a no-traffic observation window must prove actual suspension. Less polling on Railway/Hetzner improves efficiency, but it does not eliminate their running-server or resident-memory charges.

## Choice and implementation gates

1. Establish data recovery and a verified current backup before provider cutover.
2. Implement and test the provider-neutral idle-worker change separately from migration and re-chunking.
3. Measure actual awake hours, resource use, p95 latency and queue delays with real traffic.
4. If selecting Hetzner, verify stock/region and restore, patch, network, monitoring and responder arrangements. If selecting Neon, prove sleep and cold-start acceptance.
5. Rehearse an isolated migration preserving identities, versions, citations and source files. Cut over with one authoritative writer and a tested rollback boundary.

No runtime implementation, cloud capacity, availability, restore test or cost saving is certified by this document. Earlier related research: the Galing Go-template `references/database-hosting.md` (17 September 2026), which measured unintended keepalive costs in other applications, and the local Railway release recipe. Those observations inform the method, not the current app's bill.
