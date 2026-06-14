# Thin Stack Benchmarks

Source code for the benchmark experiments in:
1. **[The Return of the Thin Stack: Software in the Age of AI Synthesis](https://mantleinstitute.com/writing/return-of-the-thin-stack)**
2. **[Vibecoding for the Planet: Apportioning UK Cloud Carbon Footprints in the AI Era](https://mantleinstitute.com/writing/carbon-ops-roi)**

All code was AI-synthesised (using Gemini as the developer generating ~90% of the codebase, with Claude acting as the adversarial Red Team reviewer) from a single session exploring the resource cost of language runtime choices.

---

## What This Is

A cross-language comparison of five progressive experiments — from a simple Hello World to a secured HTTP API server — measuring binary size, peak RAM, and execution time across Assembly, C, C++, Java, Python, and TypeScript (Bun).

The core question: if AI removes the developer bottleneck that made dynamic languages attractive, does the case for thick runtime stacks still hold?

---

## Experiments

| # | Directory | Description |
|---|-----------|-------------|
| 1 | `experiment1_hello/` | Hello World across all 6 language targets |
| 2 | `experiment2_csv_filter/` | CSV file parsing and case-insensitive keyword filter |
| 3 | `experiment3_api/` | Unsecured HTTP API server serving JSON from CSV |
| 4 | `experiment4_secure_api/` | API server with three security tiers (4a: API key, 4b: HMAC, 4c: TLS) |
| 5 | `experiment5_hardened_api/` | Hardened variants with buffer-overflow resistance |
| 6 | `experiment6_density/` | Containerized microservice gateway comparison with NGINX rate-limiting |
| 7 | `experiment7_sql/` | Persistent connection SQLite database microservices compared side-by-side |
| 8 | `impact_calculations/` | NESO grid-linked Monte Carlo calculator and chart generator |

All experiments share the `data/records.csv` vinyl record database (10 records).

---

## Test Hardware

- **Machine:** Ubuntu Linux 24.04 LTS, x86-64
- **CPU:** Intel Core i7-11850H @ 2.50GHz (11th Gen, 8-core)
- **RAM:** 32 GB
- **Disk:** NVMe SSD ~954 GB

Reproduce on the same architecture for comparable binary sizes. ARM (M-series Mac) will produce different numbers.

---

## Building

### Assembly (GAS, x86-64 Linux only)
```bash
as -o hello.o hello.asm && ld -o hello_asm_bin hello.o
```

### C
```bash
gcc -O2 -o filter_records_c_bin filter_records.c
```

### C++ (experiments 3–5 require linking the parser helper)
```bash
cd libraries && g++ -O2 -shared -fPIC -o libparser.so parser_helper.cpp -lssl -lcrypto
g++ -O2 -o api_server_cpp_bin api_server.cpp -L../libraries -lparser -lssl -lcrypto
```

### Java
```bash
javac FilterRecords.java && java FilterRecords
```

### Python
```bash
python3 filter_records.py
```

### TypeScript (Bun)
```bash
bun run api_server.ts                          # interpreted
bun build --compile api_server.ts -o api_server_ts_bin  # standalone
```

---

## TLS Setup (experiments 4c and 5c)

Generate a self-signed certificate for local testing:
```bash
openssl req -x509 -newkey rsa:2048 -keyout server.key -out server.crt \
  -days 365 -nodes -subj "/CN=localhost"
```

The cert/key files are excluded from this repo — never commit private keys.

---

## Security Notes

These servers are **benchmarking experiments, not production code**. 

*   **Active Hardening (Experiment 5):** The servers in `experiment5_hardened_api/` have been physically hardened to fix critical vulnerabilities (stack smashes in the JSON accumulation loop by checking `json_ptr` offsets and increasing buffer allocation to 32KB; string overflows in the parser by replacing `strcpy` with safe `strncpy` bounds).
*   **Known Architectural Simplifications:**
    - API keys and HMAC secrets are hardcoded in source.
    - No request rate limiting or multi-threading.
    - No HMAC replay protection (no nonces/timestamps).

See the articles and [python_code_red_team.md](file:///home/pr/projects/DevLangComp/impact_calculations/python_code_red_team.md) for the full analysis of these trade-offs.

---

## Data

`data/records.csv` contains 10 vinyl record entries (Artist, Title, Year, Genre). Safe to extend for larger-scale tests.

---

## Benchmarking

Memory was measured via `/usr/bin/time -v` (MaxRSS field). Execution time was measured via the shell `time` builtin. Results were single-run on an otherwise idle machine.

Code generation and structural hardening was performed primarily by Gemini (Antigravity CLI), with Claude acting as the adversarial reviewer. Token counts and costs reflect standard pricing models.

---

## License

MIT. Benchmark code only — not production-ready.
