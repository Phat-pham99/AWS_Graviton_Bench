ARG GOARCH=amd64
FROM grafana/k6:latest AS builder
WORKDIR /scripts
COPY benchmark.js ./

# Base k6 image is multi-arch; the load generator runs on the x86_64
# control instance per PLAN.md topology (c6i.2xlarge, x86_64).
FROM grafana/k6:latest
COPY --from=builder /scripts/benchmark.js /scripts/benchmark.js
WORKDIR /scripts
ENTRYPOINT ["k6", "run"]
CMD ["benchmark.js"]
