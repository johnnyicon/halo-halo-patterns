---
id: go-react-monorepo-database-hosting
title: "Go + React Monorepo: Choosing Where Postgres Runs (Neon or Railway)"
type: architecture
status: validated
confidence: high
revision: 1
languages: [go, typescript]
frameworks:
  - name: Go
    version: "1.25"
    ecosystem: go
  - name: React
    version: "18"
    ecosystem: npm
domain: database
tags: [postgres, neon, railway, hosting, cost, keepalive, scale-to-zero]
introduced: "2026-10-15"
last_verified: "2026-10-15"
review_by: "2027-01-15"
maintainers: []
sanitized: true
related: [go-react-monorepo-stack, go-react-monorepo-layout, go-react-monorepo-operations, go-react-monorepo-scaffold]
notes: "Moved from the go-react-monorepo-template skill's references on 2026-10-15; this is now the canonical copy and the skill points here."
---

# Database hosting: serverless vs always-on, and what it actually costs

Written 2026-09-17 from measured billing across two production applications on
the same stack. Replace the estimates with real invoices as they arrive; the
method matters more than the numbers.

## The question is not "which is better"

It is **how many hours a day is the database actually awake**. That single number
decides it, and it is measurable rather than arguable.

- **Neon** bills CU-hours: compute size x awake time. Idle costs nothing. Scales
  to zero after 5 minutes by default.
- **Railway Postgres** is always-on, billed on compute x size, and **not included
  in the plan**. Idle costs the same as busy.

So Neon wins on a database that sleeps, Railway wins on one that does not, and
the crossover is arithmetic.

## The crossover

Neon Launch: **$0.106 per CU-hour**. A month is 744 hours.

Launch plan card as read on 2026-09-17 (rates move; re-read before quoting):
scale to zero after 5 minutes and autoscale to 16 CU included; 10 branches and
500 GB public transfer per project; storage $0.35/GB-month; instant restore
$0.20/GB-month. On a small database every line but compute rounds to cents —
one account's August storage across all branches was five cents.

Railway Postgres for a small database: **$5-15/month** — derived from Railway's
own guidance (a process pinned at 1 vCPU is near $20/month, memory about half
that per unit), *not* from an invoice. Treat it as an estimate until replaced.

Break-even = Railway monthly cost / $0.106:

| If Railway costs | Neon matches it at | At 1 CU, that is | Roughly |
|---|---|---|---|
| $5/month | 47 CU-hours | 6% of the month | ~1.5 hours/day awake |
| $10/month | 94 CU-hours | 13% of the month | ~3 hours/day awake |
| $15/month | 142 CU-hours | 19% of the month | ~4.5 hours/day awake |

**Rule of thumb: past roughly 2-5 hours a day of genuine database activity at
1 CU, always-on is cheaper.** Below that, serverless is, often by a lot.

**It is CU-hours, not clock hours.** Size counts. A database autoscaled to 4 CU
for one hour spends 4 CU-hours. A busy application crosses over far sooner in
wall-clock terms than this table suggests, so compute the crossover from CU-hours
and only then translate to hours of the day.

### What one endpoint costs if it never sleeps

`autoscaling_limit_min_cu` is a cost setting as much as a performance one. An
endpoint pinned awake bills at least its floor for every hour of the month:

| Floor (min CU) | CU-hours if awake 744 h | Cost at $0.106 |
|---|---|---|
| 0.25 | 186 | ~$20/month |
| 0.5 | 372 | ~$39/month |
| 1 | 744 | ~$79/month |

Two lessons from measured accounts. A quiet public site with two endpoints at a
0.25 floor billed **~1.0 CU average, twice its floor** — autoscaling lifted a
pinned, near-idle endpoint above its minimum, so the floor is a lower bound on
the damage, not the damage. And an internal tool configured `min_cu = max_cu = 1`
costs 40 cents *only because it suspends*; the same setting on a pinned endpoint
is $79/month. Check the floor before trusting a small bill to stay small.

## Three measured reference points

| Workload | CU-hours/month | Utilisation | Neon cost | Verdict |
|---|---|---|---|---|
| Internal tool, small team, suspends properly | 3.8 | 0.5% | **$0.40** | Neon, overwhelmingly |
| Same stack with a 4-minute keepalive on two endpoints | 713.6 | 96% | **$75.64** | Neither — fix the code |
| Public site, low traffic, keepalive removed | ~90 (projected; measure due 2026-10-02) | ~12% | ~$9.50 | Genuinely a coin toss |

The third row is the honest one. Once a low-traffic site stops pinning its
database awake, it lands near the crossover and the answer depends on real
traffic. That is where you measure rather than argue.

## The failure mode that dominates everything else

**Neon's model punishes anything that keeps the connection warm**, and the waste
is invisible until the invoice arrives.

One application carried a goroutine pinging the database every four minutes to
avoid cold starts. Reasonable on a free plan; on usage-based billing it turned
every hour into a billed hour on two endpoints — **96% utilisation, about
$900/year, for a site nobody was using.** A second endpoint appearing (staging
going live) doubled it overnight, and the step change in the invoice was the
clue that found it.

Audit all five before choosing or blaming a provider:

1. **Keepalive loops.** Any goroutine, timer or job pinging the database to avoid
   cold starts. This is the big one.
2. **Health checks that query.** A liveness probe running SQL keeps compute awake
   forever. Make `/health` a static string; check the database in a separate
   readiness endpoint that the platform does not poll on a timer.
3. **Connection pools that stay warm.** `MinConns > 0` is the trap: the pool
   re-opens connections to hold its minimum, and each open is server traffic.
   pgx's `HealthCheckPeriod` on its own is client-side (it retires expired and
   idle connections and tops up to `MinConns`) and sends nothing when
   `MinConns=0`, so a 30-second period with a zero minimum is harmless. Belt
   and braces: a short `MaxConnIdleTime` (one application uses 1 minute) so
   idle connections drain well inside the suspend window.
4. **Cron and pollers** running more often than the suspend timeout.
5. **Monitoring** that polls the database for metrics.
6. **Traffic that is not yours but counts anyway.** An external uptime monitor
   pointed at a page that queries the database, crawlers on a public site,
   SSR prefetching, an admin tool left open. None of this is in your code, all
   of it is awake time. It is the first place to look when the endpoint stays
   `active` after the code is clean.

**Every deployment of the binary is a keepalive client.** The keepalive above
was one goroutine in one file, but the same binary ran in a production
environment and a staging environment, each against its own branch. The bill
doubled the day staging went live, without a line of code changing. Count
environments, not codebases: one warm loop times N environments is N pinned
endpoints.

### Finding it in code

The loop is usually small, old, and commented as a favour. Search for the
mechanism and the excuse, and date it:

```bash
grep -rn 'NewTicker\|time.Tick(\|AfterFunc\|cron\.\|\.Ping(' --include='*.go' . | grep -v _test
grep -rn -i 'keepalive\|autosuspend\|cold start' --include='*.go' .
git log -S'NewTicker' --format='%h %ad %s' --date=short -- <file>
```

The commit that added it will say why ("Free plan enforces a 5-minute idle
timeout"). That reason usually stopped being true the day the plan changed;
nobody went back because nothing broke. Also read the platform's deploy config
for the health-check path and confirm the handler behind it is static.

The inverse is worth naming too: **Railway's model punishes none of this, which
means it hides it.** Migrating to escape a keepalive does not remove the waste,
it makes it invisible by bundling it into an always-on bill. Fix the cause first,
then choose the host.

## What else separates them

**Branching.** Neon branches are copy-on-write snapshots of real data, created in
seconds for near-zero storage. Used in practice for per-environment databases,
pre-deploy snapshots, and resetting staging from production with a PII scrub.
Railway environments are *not* equivalent — they give a separate empty database,
not a copy of production. If that workflow is load-bearing, it is a real cost of
moving, and it will not show up in a price comparison.

**Cold starts.** Neon's first request after the idle window waits about a second.
On a well-optimised application this can become the single largest latency a user
meets — worth measuring against the rest of the request budget rather than
assumed negligible. The fix is Neon's own scale-to-zero setting, chosen knowingly
with the bill in view. Never a keepalive.

**Network path.** Railway Postgres sits on the project's private network with the
app. Neon is reached over the public internet, so **region matters enormously**:
an app in one region and a database in another pays roughly 60ms per round trip,
and an endpoint making a dozen sequential queries wears all of it. Co-locating
one application's services with its database took a request from ~2.4s to ~0.15s
for two CLI commands and no data movement — a larger win than any query
optimisation made the same day.

**PITR and backups.** Both have them. Not a differentiator. Railway's is opt-in,
archives WAL to a bucket with roughly a four-week window, and those uploads bill
as service egress — small, but it is a line on the invoice Neon does not have.

**Railway has its own version of the trap.** Railway can sleep an app service
after ten minutes without outbound traffic, and its docs say plainly that a
held database connection pool counts as outbound and prevents sleep. So an
always-on app on Railway is often always-on for the same reason a Neon endpoint
was: the pool. Do not expect Railway's sleeping to apply to the database itself,
and do not expect it to rescue a service that holds a pool.

**Vendor count.** Railway is one bill and one support surface. Neon is a second.

## Choosing, in order

1. **Audit the five failure modes above.** A database pinned awake by your own
   code costs too much on any host. Do this before comparing prices.
2. **Measure CU-hours for a full billing period**, per project, after the audit.
3. **Compare against the crossover table.** Under ~2 hours a day awake, stay
   serverless. Over ~5, move or accept always-on. In between, the difference is
   small enough that branching, cold starts and vendor count should decide it.
4. **Split by environment if it helps.** Staging is idle most of the day and
   rarely justifies always-on, even when production does. A hybrid is legitimate,
   at the cost of a second vendor.

## Measuring Neon usage

The console shows account-level charges. **An account-level invoice covering more
than one project supports any story you like** — get the per-project split before
deciding anything. In one case a bill was attributed to the wrong application
until this call was made; the real answer was 1% versus 99%.

Authenticate with `neonctl auth` (browser OAuth; do not put an API key in a
document or a chat), then:

```bash
neonctl projects list --org-id <org-id> --output json

TOKEN=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.config/neonctl/credentials.json')))['access_token'])")

# per-project compute over time — monthly or daily granularity
curl -s "https://console.neon.tech/api/v2/consumption_history/v2/projects?org_id=<org-id>&from=<ISO>&to=<ISO>&granularity=monthly&metrics=compute_unit_seconds&limit=100" \
  -H "Authorization: Bearer $TOKEN"

# endpoint autosuspend settings and live state
curl -s "https://console.neon.tech/api/v2/projects/<project-id>/endpoints" \
  -H "Authorization: Bearer $TOKEN"
```

`compute_unit_seconds / 3600` = CU-hours, which reconciles with the invoice.

On endpoints, `suspend_timeout_seconds: 0` means **Neon's default 5 minutes, not
disabled** (disabled is `-1`). An endpoint reading `active` around the clock with
the default timeout means something is querying it, not that a setting is wrong.

With `granularity=daily`, the value sits at `consumption[].metrics[0].value`
(monthly puts it at `compute_unit_seconds` directly). The `to` bound must be
strictly after `from` at the chosen granularity; asking for a monthly series
ending mid-month returns an error rather than a partial month.

### Reading the daily numbers

The daily series is the diagnostic; the monthly total only says how much.

- **A flat line at 24 x (sum of floors) is a pinned endpoint.** Two endpoints at
  0.25 that read 12.0 CU-hours every day, or 24.0 every day, are not serving
  traffic — traffic varies. Something is holding them awake around the clock.
- **The ratio above the floor is autoscaling.** 24.0 a day on a 0.5 total floor
  means the endpoints averaged 1.0 CU. On a site with almost no users that is
  worth a look in Neon's monitoring before choosing a Railway instance size.
- **A step on a specific day is a deployment or configuration event.** Pull the
  daily series across the step and match the date to the deploy log. One
  measured account stepped 24 -> 13 CU-hours/day three days before anyone
  touched it, for a reason still unexplained; the doc records it rather than
  smoothing it over.

### Verifying the fix

Removing a keepalive is only real once it is running in **every environment that
executes the binary**. Check each deploy branch, not just main:

```bash
git log origin/<app>/production -3 --oneline
git log origin/<app>/staging -3 --oneline
```

Then watch the endpoints. Within a few minutes of the deploy, with no traffic,
`current_state` should read `idle` and `last_active` should stop advancing. If
production is still `active` and staging is `idle`, the cause is either the
production deploy not having happened or item 6 above — real external traffic.
Set a dated reminder to pull the daily series after the next full billing
period and compare it to the flat line you started from.

## Track it

Keep a cost file in the repository — invoices, CU-hours, utilisation, and the
reasoning behind each decision including the ones later reversed. The step
changes are the diagnostic: a bill that jumps and then goes flat is a
configuration or deployment event, not organic growth, and the date it jumped
narrows the search to whatever shipped that week.
