# Red Team Analysis: Python ROI Utilities

This document evaluates [roi_calculator.py](file:///home/pr/projects/DevLangComp/roi_calculator.py) and [roi_chart.py](file:///home/pr/projects/DevLangComp/roi_chart.py) for reliability, error handling, rate-limiting, and mathematical rigor.

---

## 1. Network Reliability & API Vulnerabilities

*   **Blocking Socket (No Timeout):**
    *   *The Bug:* `urllib.request.urlopen` is invoked without an explicit `timeout` parameter. If the NESO API hangs or suffers from severe network congestion, the script will block indefinitely, locking the CLI thread or CI/CD pipelines.
*   **API Rate Limit / Denial of Service:**
    *   *The Bug:* The backtracking loop `while offset > 0` executes up to 15-30 sequential HTTP calls in a tight loop to scan records backwards by chunks of 100. NESO's official API guidelines recommend a limit of **2 requests per minute**. This script will trigger rate-limiting controls (HTTP 429) or IP bans on first execution in an unprimed environment.
*   **Static Resource ID Dependency:**
    *   *The Bug:* The resource ID `0e5fde43-2de7-4fb4-833d-c7bca3b658b0` is hardcoded. CKAN resource IDs frequently change when datasets are updated, archived, or split by the publisher. Once updated, the API queries will immediately fail, forcing silent fallbacks.

---

## 2. Mathematical & Scientific Assumptions

*   **Arbitrary Energy Saving Estimates:**
    *   *The Flaw:* The assumption of `1 Wh` (0.001 kWh) energy savings per service-hour for thin-stack vs. thick-stack workloads is an unmeasured estimate. In reality, CPU idle power draw does not scale linearly with memory consumption. Unless backed by direct hardware power measurements (using intel-RAPL or PMUs), this forms a weak point for scientific peer review.
*   **Static Cloud and Hosting Pricing:**
    *   *The Flaw:* AWS Fargate pricing ($0.004445/GB-hr) and hosting spend per kW-year ($1,500) are hardcoded. This ignores pricing updates, regional differences (UK vs. US Fargate pricing varies by up to 20%), and standard corporate volume discounts.
*   **Symmetric Optimization Efficiency:**
    *   *The Flaw:* The macro calculation assumes that saving memory on 25% of data center workloads scales directly to a 20% overall power reduction on that hardware. This ignores hypervisor virtualization overhead, base motherboard power draws, and storage/network energy costs which remain constant regardless of container memory consumption.

---

## 3. Code Quality & Exception Handling

*   **Silent Exceptions in Charting Script:**
    *   *The Bug:* In `roi_chart.py`, the `fetch_latest_neso_intensity` helper uses a blank `except Exception: pass` block. If the API fails, the script silently uses the fallback values without warning the user, hiding potential data collection errors.
*   **Lack of Input Validation:**
    *   *The Bug:* If the API returns a malformed actual value or a string that cannot be cast to `float` (e.g. `"N/A"`), the conversion `float(r["actual"])` will crash the script with a `ValueError`.
