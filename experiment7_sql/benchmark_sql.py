import subprocess
import time
import threading
import json
import csv
from concurrent.futures import ThreadPoolExecutor
import requests

def run_bash(cmd):
    wrapped_cmd = f"newgrp docker <<EONG\n{cmd}\nEONG"
    res = subprocess.run(wrapped_cmd, shell=True, capture_output=True, text=True)
    return res.stdout.strip()

def get_image_sizes():
    stdout = run_bash("docker images --format '{{.Repository}}:{{.Size}}'")
    sizes = {}
    for line in stdout.split('\n'):
        if ':' in line:
            repo, size = line.split(':', 1)
            if 'experiment7_sql' in repo:
                sizes[repo] = size
    return sizes

def get_container_stats():
    stdout = run_bash("docker stats --no-stream --format '{{.Name}},{{.CPUPerc}},{{.MemUsage}}'")
    stats = {}
    for line in stdout.split('\n'):
        parts = line.split(',')
        if len(parts) == 3:
            name, cpu, mem = parts
            name = name.strip()
            stats[name] = {
                'cpu': cpu.strip(),
                'mem': mem.split('/')[0].strip()
            }
    return stats

def run_load_test(port, num_requests=500, concurrency=10):
    url = f"http://localhost:{port}/api/records?q=Rock"
    latencies = []
    
    peaks = {'cpu': 0.0, 'mem': '0B'}
    stop_monitoring = False
    
    def monitor_stats():
        container_map = {
            8081: 'experiment7_sql-api-assembly-1',
            8082: 'experiment7_sql-api-cpp-1',
            8083: 'experiment7_sql-api-ts-1'
        }
        c_name = container_map[port]
        while not stop_monitoring:
            stats = get_container_stats()
            if c_name in stats:
                try:
                    cpu_val = float(stats[c_name]['cpu'].replace('%', ''))
                    if cpu_val > peaks['cpu']:
                        peaks['cpu'] = cpu_val
                    peaks['mem'] = stats[c_name]['mem']
                except Exception:
                    pass
            time.sleep(0.1)

    monitor_thread = threading.Thread(target=monitor_stats)
    monitor_thread.start()

    def send_request():
        try:
            start = time.perf_counter()
            r = requests.get(url, timeout=5)
            latencies.append((time.perf_counter() - start) * 1000) # ms
        except Exception as e:
            pass

    start_test = time.perf_counter()
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(send_request) for _ in range(num_requests)]
        for f in futures:
            f.result()
    total_time = (time.perf_counter() - start_test) * 1000

    stop_monitoring = True
    monitor_thread.join()

    if not latencies:
        return 0, 0, 0, peaks

    avg_lat = sum(latencies) / len(latencies)
    min_lat = min(latencies)
    max_lat = max(latencies)
    
    return avg_lat, min_lat, max_lat, peaks

def main():
    print("=== Executing Thin Stack SQL Benchmark Suite ===")
    
    print("\n[1/3] Querying Docker Image Sizes...")
    img_sizes = get_image_sizes()
    for repo, sz in img_sizes.items():
        print(f"  {repo}: {sz}")

    # Baseline resource stats
    print("\n[2/3] Capturing Baseline Resource Footprints...")
    baselines = get_container_stats()
    
    # Load testing targets
    print("\n[3/3] Load Testing SQL Endpoints (500 requests @ 10 concurrency)...")
    
    targets = [
        ('Assembly', 8081, 'experiment7_sql-api-assembly-1', 'api-assembly'),
        ('C++', 8082, 'experiment7_sql-api-cpp-1', 'api-cpp'),
        ('TypeScript', 8083, 'experiment7_sql-api-ts-1', 'api-ts')
    ]
    
    results = []
    
    for label, port, container_name, img_suffix in targets:
        print(f"  Benchmarking {label} SQL API on port {port}...")
        avg, min_l, max_l, peak_stats = run_load_test(port)
        
        base_mem = baselines.get(container_name, {}).get('mem', 'N/A')
        
        image_size = 'N/A'
        for repo, sz in img_sizes.items():
            if img_suffix in repo:
                image_size = sz
                break
                
        results.append({
            'Language': label,
            'Port': port,
            'Image Size': image_size,
            'Baseline Memory': base_mem,
            'Peak Memory': peak_stats['mem'],
            'Peak CPU': f"{peak_stats['cpu']}%",
            'Avg Latency (ms)': f"{avg:.2f}",
            'Min Latency (ms)': f"{min_l:.2f}",
            'Max Latency (ms)': f"{max_l:.2f}"
        })
        time.sleep(1)

    # Save to CSV
    csv_file = 'benchmark_sql_results.csv'
    with open(csv_file, mode='w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=results[0].keys())
        writer.writeheader()
        writer.writerows(results)
        
    print(f"\nBenchmark results saved successfully to: {csv_file}")
    
    # Print Markdown Summary
    print("\n### SQL Benchmark Summary Table")
    print("| Language | Port | Image Size | Baseline RAM | Peak RAM | Peak CPU | Avg Latency |")
    print("| --- | --- | --- | --- | --- | --- | --- |")
    for r in results:
        print(f"| {r['Language']} | {r['Port']} | {r['Image Size']} | {r['Baseline Memory']} | {r['Peak Memory']} | {r['Peak CPU']} | {r['Avg Latency (ms)']} ms |")

if __name__ == '__main__':
    main()
