# Build stage: cross-compile for a specific target architecture.
#
# Build with `--build-arg GOARCH=amd64` for the x86_64 control group and
# `--build-arg GOARCH=arm64` for the ARM64 (Graviton) test group so the source
# workload is identical across architectures.
ARG GOARCH=amd64
FROM golang:1.22 AS builder
ARG GOARCH=amd64
WORKDIR /src
COPY go.mod ./
COPY main.go ./
ENV CGO_ENABLED=0 GOOS=linux GOARCH=${GOARCH}
RUN go build -trimpath -ldflags="-s -w" -o /out/bench .

FROM gcr.io/distroless/static-debian12:latest
ARG GOARCH=amd64
ENV GOARCH=${GOARCH}
EXPOSE 8080
COPY --from=builder /out/bench /bench
USER nonroot
ENTRYPOINT ["/bench"]
