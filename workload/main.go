// Benchmark microservice for the ARM64 vs x86_64 empirical study.
//
// Exposes three workload endpoints representative of compute-bound backend
// microservices:
//
//	/cpu      -- CPU-bound compute (floating point / hashing)
//	/json     -- JSON serialization + allocation churn
//	/mixed    -- combined compute + serialization
//	/memory   -- bounded in-memory working set scan
//	/healthz  -- liveness probe (no measurement)
//
// The binary is architecture-agnostic: cross-compile with GOOS=linux and
// GOARCH={amd64,arm64} to produce bit-for-bit identical source workloads for
// both control (x86_64) and test (Graviton/ARM64) groups.
//
// Author & Principal Researcher: Pham Hong Phat.
package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"runtime"
	"time"
)

const (
	envPort     = "PORT"
	defaultPort = "8080"
	maxWork     = 3_000_000 // iterations per /cpu request
	jsonDepth   = 8         // nesting depth for /json payload
	memBytes    = 64 << 20  // 64 MiB working set for /memory
)

// payload mirrors a realistic microservice response document.
type payload struct {
	RequestID string        `json:"request_id"`
	Timestamp time.Time     `json:"timestamp"`
	Arch      string        `json:"arch"`
	Samples   []sampleValue `json:"samples"`
	Nested    nestedObject  `json:"nested"`
	Hash      string        `json:"hash"`
}

type sampleValue struct {
	ID    int     `json:"id"`
	Value float64 `json:"value"`
	Label string  `json:"label"`
}

type nestedObject struct {
	Level1 map[string][]int `json:"level1"`
	Level2 struct {
		Flag bool   `json:"flag"`
		Note string `json:"note"`
	} `json:"level2"`
}

// cpuWork performs deterministic floating-point compute bound by a fixed
// iteration count so that both architectures do identical work.
func cpuWork(n int) uint64 {
	var acc uint64
	x := 1.000001
	for i := 0; i < n; i++ {
		x = x*1.0001 - 0.0001
		if i%97 == 0 {
			acc ^= uint64(i)
		}
	}
	return acc
}

func sha256Hex(s string) string {
	sum := sha256.Sum256([]byte(s))
	return fmt.Sprintf("%x", sum)
}

func buildPayload(id string) payload {
	p := payload{
		RequestID: id,
		Timestamp: time.Now().UTC(),
		Arch:      runtime.GOARCH + ":" + runtime.GOOS,
	}
	for i := 0; i < 128; i++ {
		p.Samples = append(p.Samples, sampleValue{
			ID:    i,
			Value: float64(i*31) / 7.0,
			Label: fmt.Sprintf("label-%d", i),
		})
	}
	p.Nested.Level1 = map[string][]int{
		"buckets":   {1, 2, 3, 4, 5},
		"latencies": {10, 25, 50, 90, 99},
	}
	p.Nested.Level2.Flag = true
	p.Nested.Level2.Note = "graviton-vs-x86-benchmark"
	p.Hash = sha256Hex(id)
	return p
}

// memScan walks a fixed-size byte slice to simulate a bounded working-set scan.
func memScan(buf []byte) uint64 {
	var sum uint64
	for i := 0; i < len(buf); i += 64 {
		sum += uint64(buf[i])
	}
	return sum
}

func handleCPU(w http.ResponseWriter, r *http.Request) {
	_ = cpuWork(maxWork)
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]uint64{"checksum": cpuWork(maxWork % 1000)})
}

func handleJSON(w http.ResponseWriter, r *http.Request) {
	p := buildPayload(fmt.Sprintf("%d", time.Now().UnixNano()))
	w.Header().Set("Content-Type", "application/json")
	// Pre-marshal then write to keep the encode step consistent and measurable.
	data, err := json.Marshal(p)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	_, _ = w.Write(data)
}

func handleMixed(w http.ResponseWriter, r *http.Request) {
	_ = cpuWork(maxWork / 3)
	p := buildPayload(fmt.Sprintf("%d", time.Now().UnixNano()))
	w.Header().Set("Content-Type", "application/json")
	data, err := json.Marshal(p)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	checksum := cpuWork(maxWork % 777)
	_ = checksum
	_, _ = w.Write(data)
}

func handleMemory(w http.ResponseWriter, r *http.Request) {
	buf := make([]byte, memBytes)
	// Deterministic fill avoids allocator-variance between architectures.
	for i := range buf {
		buf[i] = byte(i * 7)
	}
	sum := memScan(buf)
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]uint64{"checksum": sum})
}

func handleHealthz(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write([]byte(`{"status":"ok"}`))
}

func main() {
	port := os.Getenv(envPort)
	if port == "" {
		port = defaultPort
	}

	go func() {
		// Warm-up to reduce JIT/first-request variance before measurement.
		time.Sleep(3 * time.Second)
		_ = cpuWork(maxWork / 100)
		_ = buildPayload("warmup")
		log.Println("warm-up complete; accepting load")
	}()

	engine := http.NewServeMux()
	engine.HandleFunc("GET /cpu", handleCPU)
	engine.HandleFunc("GET /json", handleJSON)
	engine.HandleFunc("GET /mixed", handleMixed)
	engine.HandleFunc("GET /memory", handleMemory)
	engine.HandleFunc("GET /healthz", handleHealthz)

	log.Printf("benchmark microservice listening on :%s", port)
	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           engine,
		ReadHeaderTimeout: 5 * time.Second,
	}
	if err := srv.ListenAndServe(); err != nil {
		log.Fatalf("server exited: %v", err)
	}
}
