#!/usr/bin/env python3
import urllib.request
import json
import numpy as np

def print_section(title):
    print("\n" + "=" * 80)
    print(f" {title.upper()} ")
    print("=" * 80)

def fetch_latest_neso_intensity():
    """
    Fetches the latest actual carbon intensity (gCO2/kWh) for the UK grid
    using a bulk query to avoid rate limits and timeouts.
    """
    resource_id = '0e5fde43-2de7-4fb4-833d-c7bca3b658b0'
    base_url = 'https://api.neso.energy/api/3/action/datastore_search'
    
    print("Connecting to NESO CKAN API...")
    try:
        init_url = f"{base_url}?resource_id={resource_id}&limit=1"
        req = urllib.request.Request(init_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as conn:
            res = json.loads(conn.read().decode('utf-8'))
        total = res['result']['total']

        limit = 2500
        offset = max(0, total - limit)
        search_url = f"{base_url}?resource_id={resource_id}&limit={limit}&offset={offset}"
        req = urllib.request.Request(search_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as conn:
            records = json.loads(conn.read().decode('utf-8'))['result']['records']
        
        for r in reversed(records):
            if r.get('actual') is not None:
                try:
                    return {
                        "datetime": r["datetime"],
                        "intensity": float(r["actual"]),
                        "index": r.get("index", "unknown")
                    }
                except (ValueError, TypeError):
                    continue
    except urllib.error.URLError as e:
        print(f"Warning: Connection error to NESO API ({e.reason}). Using fallback average.")
    except json.JSONDecodeError:
        print("Warning: Received invalid JSON response from NESO API. Using fallback average.")
    except Exception as e:
        print(f"Warning: Unexpected API query failure ({e}). Using fallback average.")
    
    return {"datetime": "N/A (Fallback)", "intensity": 149.0, "index": "moderate"}

def run_calculation():
    # ── Fetch UK Carbon Intensity ──
    grid_data = fetch_latest_neso_intensity()
    uk_intensity_mean = grid_data["intensity"]
    
    print_section("UK Operational Baselines (NESO API Live Data)")
    print(f"  Live Carbon Intensity (Mean):             {uk_intensity_mean} g CO2e / kWh")
    print(f"  NESO Index:                               {grid_data['index'].upper()}")
    print(f"  Thick Stack RAM Baseline (Python/Node):   40.0 MB")
    print(f"  Thin Stack RAM Baseline (Assembly/C++):    1.4 MB")
    print(f"  AWS Fargate RAM Rate:                     $0.004445 / GB-hour")

    # ── Statistical Adjustments (Addressing Critique) ──
    # 1. Non-linear Power Intercept: Server idle draw is not saved.
    #    We model baseline container overhead as 2.0W (not saved) + dynamic draw of 0.5W (saved).
    #    Saved power per service is set to 0.5 Wh (0.0005 kW) instead of the naive 1.0 Wh.
    saved_power_per_service_kw = 0.0005
    
    # 2. Monte Carlo Simulation Setup
    #    Draw 10,000 samples to propagate parameter uncertainty:
    #    - Convertible Ratio: Normal(0.25, 0.03) -> 25% of workloads are convertible
    #    - Optimization Efficiency: Normal(0.20, 0.02) -> 20% power reduction on optimized nodes
    #    - Carbon Intensity: Normal(mean, mean * 0.15) -> Models diurnal covariance variance
    #    - AWS Fargate Cost: Normal(0.004445, 0.004445 * 0.08) -> Regional price variance
    N = 10000
    rng = np.random.default_rng(42) # Set seed for reproducible science
    
    sim_convertible_ratio = rng.normal(0.25, 0.03, N)
    sim_opt_efficiency = rng.normal(0.20, 0.02, N)
    sim_intensity = rng.normal(uk_intensity_mean, uk_intensity_mean * 0.15, N)
    sim_fargate_rate = rng.normal(0.004445, 0.004445 * 0.08, N)

    # ── Macro-Scale UK National Grid Analysis ──
    # Global Data Center Report (2026): UK consumes 2.0 GW (5.8% of UK's total electricity).
    uk_datacenter_draw_kw = 2000000.0
    
    # Simulate distributions
    sim_convertible_draw_kw = uk_datacenter_draw_kw * sim_convertible_ratio
    sim_power_saved_kw = sim_convertible_draw_kw * sim_opt_efficiency
    sim_annual_kwh_saved = sim_power_saved_kw * 8760
    sim_annual_tonnes_co2_saved = (sim_annual_kwh_saved * sim_intensity) / 1000000.0
    sim_annual_financial_saved = sim_power_saved_kw * 1500
    sim_grid_saved_pct = 5.8 * sim_convertible_ratio * sim_opt_efficiency

    # Helper to format confidence intervals
    def format_ci(arr):
        mean = np.mean(arr)
        ci_lower = np.percentile(arr, 2.5)
        ci_upper = np.percentile(arr, 97.5)
        return f"{mean:,.2f} [95% CI: {ci_lower:,.2f}, {ci_upper:,.2f}]"

    print_section("UK National Impact Projections (Monte Carlo Model)")
    print(f"  Potential Grid Power Reclaimed:           {format_ci(sim_power_saved_kw / 1000.0)} MW continuous")
    print(f"  National Grid Power Saved (% of Total):   {format_ci(sim_grid_saved_pct)}% of entire UK Grid")
    print(f"  Annual Carbon Prevented (Tonnes):         {format_ci(sim_annual_tonnes_co2_saved)} tonnes CO2e")
    print(f"  Estimated National Energy Savings (USD):  ${format_ci(sim_annual_financial_saved)}/year")

    # ── 2030 Projections (Capacity Doubles to 4.0 GW) ──
    draw_2030_kw = 4000000.0
    sim_convertible_2030_kw = draw_2030_kw * sim_convertible_ratio
    sim_power_saved_2030_kw = sim_convertible_2030_kw * sim_opt_efficiency
    sim_annual_kwh_2030_saved = sim_power_saved_2030_kw * 8760
    sim_annual_tonnes_co2_2030_saved = (sim_annual_kwh_2030_saved * sim_intensity) / 1000000.0
    sim_grid_saved_2030_pct = 11.6 * sim_convertible_ratio * sim_opt_efficiency
    sim_annual_financial_2030_saved = sim_power_saved_2030_kw * 1500

    print_section("UK 2030 Projections (Monte Carlo Double Capacity Model)")
    print(f"  Potential Grid Power Reclaimed:           {format_ci(sim_power_saved_2030_kw / 1000.0)} MW continuous")
    print(f"  National Grid Power Saved (% of Total):   {format_ci(sim_grid_saved_2030_pct)}% of entire UK Grid")
    print(f"  Annual Carbon Prevented (Tonnes):         {format_ci(sim_annual_tonnes_co2_2030_saved)} tonnes CO2e")
    print(f"  Estimated National Energy Savings (USD):  ${format_ci(sim_annual_financial_2030_saved)}/year")

    # ── Organization Conversions ──
    scenarios = {
        "Minimal (5% Conversion)": 0.05,
        "Median (25% Conversion)": 0.25,
        "Maximum (60% Conversion)": 0.60
    }

    org_scales = [
        {"name": "Micro (10 total services)", "total_services": 10},
        {"name": "Middle (1,000 total services)", "total_services": 1000},
        {"name": "Macro (100,000 total services)", "total_services": 100000}
    ]

    for org in org_scales:
        print_section(f"Organization Scale: {org['name']}")
        total = org["total_services"]
        
        for name, pct in scenarios.items():
            converted = int(total * pct)
            if converted == 0:
                continue
                
            synthesis_cost = converted * 0.0030
            
            # Simulate cost distributions
            thick_ram_gb = (converted * 40.0) / 1024.0
            sim_thick_annual_cost = thick_ram_gb * sim_fargate_rate * 24 * 365
            
            thin_ram_gb = (converted * 1.4) / 1024.0
            sim_thin_annual_cost = thin_ram_gb * sim_fargate_rate * 24 * 365
            
            sim_annual_savings = sim_thick_annual_cost - sim_thin_annual_cost
            
            # Carbon intensity calculation incorporating 0.5W dynamic saved power
            sim_org_kwh_saved = converted * saved_power_per_service_kw * 24 * 365
            sim_org_carbon_saved_kg = (sim_org_kwh_saved * sim_intensity) / 1000.0

            print(f"\n[{name}]")
            print(f"  -> Converted Services:      {converted} of {total}")
            print(f"  -> Upfront AI Cost (CapEx): ${synthesis_cost:.4f}")
            print(f"  -> Annual Cost Savings (USD): ${format_ci(sim_annual_savings)}")
            print(f"  -> Annual Carbon Offset (kg): {format_ci(sim_org_carbon_saved_kg)}")

if __name__ == "__main__":
    run_calculation()
