# Observability Cost Assessment — Grafana + Prometheus

## Summary

The observability stack is **Grafana + Prometheus** (self-hosted, OSS) running on
a single EC2 instance (`t3.medium`, 2 vCPU / 4 GiB) with a 40 GB gp3 root
volume. See `terraform/modules/dashboard/module.tf:21-44`.

> Note: there is no managed product named "Observatory" — that term is Grafana
> Cloud marketing. This stack is the classic self-hosted combination.

**Estimated cost: ~$33.57 / month** (us-east-1, on-demand).

## Cost breakdown

| Item                | Approx. price     | Monthly (730 h) |
|---------------------|-------------------|-----------------|
| `t3.medium` EC2     | ~$0.0416 / hr     | ~$30.37         |
| gp3 40 GB storage   | $0.08 / GB / mo   | ~$3.20          |
| Data transfer out   | first 100 GB free, then $0.09 / GB | varies (usually free) |
| NAT gateway         | pooled (not extra)| —               |
| **Total**           |                   | **~$33.57**     |

For a **2-week benchmark sprint**: ~$16.80.

## Cheaper options

1. **Spot instance** (`instance_market_options` on the `aws_instance`) — saves
   ~50–70%; tolerable for a short-lived observability host.
2. **Downsize to `t3.small`** (2 vCPU, 2 GiB, ~$15/mo) — ample for 3 scrape
   targets at 10s intervals. The 4 GiB of `t3.medium` is overkill unless storing
   weeks of history.
3. **Destroy between runs** — tear down the dashboard module and re-provision
   per run; state is ephemeral if you export before each run.

## Managed alternatives (not cheaper)

| Service | Reason not cheaper |
|---------|--------------------|
| Amazon Managed Prometheus + Managed Grafana | ~$20–40/mo + per-metric charges; loses 10s scrape control and Kepler/Scaphandre data |
| Datadog / New Relic | $15+ per host/mo + per-metric; at 4 hosts & 10s cadence, >$100/mo |
| CloudWatch alone | near-free for 3 instances but cannot expose Kepler/Scaphandre — defeats the research purpose |

## Conclusion

Self-hosted Grafana + Prometheus is one of the cheapest ways to collect
energy/perf telemetry at a 10s scrape interval. At ~$34/month it is a trivial
share of the workload cost (the `c6i.xlarge` + `c7g.xlarge` SUTs cost
~$60–70/month combined before dashboards).
