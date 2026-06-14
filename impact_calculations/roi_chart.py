#!/usr/bin/env python3
import os
import matplotlib.pyplot as plt
import numpy as np
import urllib.request
import json

def fetch_latest_neso_intensity():
    resource_id = '0e5fde43-2de7-4fb4-833d-c7bca3b658b0'
    base_url = 'https://api.neso.energy/api/3/action/datastore_search'
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
                    return float(r["actual"])
                except (ValueError, TypeError):
                    continue
    except Exception:
        pass
    return 149.0 # Fallback

def generate_charts():
    uk_intensity_mean = fetch_latest_neso_intensity()
    categories = ['Micro\n(10 Services)', 'Middle\n(1k Services)', 'Macro\n(100k Services)']
    
    # ── Monte Carlo Setup ──
    N = 10000
    rng = np.random.default_rng(42)
    sim_intensity = rng.normal(uk_intensity_mean, uk_intensity_mean * 0.15, N)
    sim_fargate_rate = rng.normal(0.004445, 0.004445 * 0.08, N)
    
    # Scenario converted service counts
    scenarios = {
        'min': {'services': [0, 50, 5000], 'label': 'Minimal (5% Converted)', 'color': '#4F46E5'},
        'med': {'services': [2, 250, 25000], 'label': 'Median (25% Converted)', 'color': '#06B6D4'},
        'max': {'services': [6, 600, 60000], 'label': 'Maximal (60% Converted)', 'color': '#10B981'}
    }

    # Intercept-adjusted power model: 0.5W dynamic power saved per service
    saved_power_kw = 0.0005

    plt.style.use('dark_background')
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
    
    x = np.arange(len(categories))
    width = 0.25

    # Compute statistics for each scenario and scale
    for i, (key, data) in enumerate(scenarios.items()):
        means_savings = []
        errs_savings = []
        means_carbon = []
        errs_carbon = []
        
        for count in data['services']:
            if count == 0:
                means_savings.append(1e-10) # Prevent zero on log scale
                errs_savings.append([0, 0])
                means_carbon.append(1e-10)
                errs_carbon.append([0, 0])
                continue

            # Financial savings distributions
            thick_ram_gb = (count * 40.0) / 1024.0
            sim_thick_cost = thick_ram_gb * sim_fargate_rate * 24 * 365
            thin_ram_gb = (count * 1.4) / 1024.0
            sim_thin_cost = thin_ram_gb * sim_fargate_rate * 24 * 365
            sim_savings = sim_thick_cost - sim_thin_cost
            
            mean_sav = np.mean(sim_savings)
            ci_sav = np.percentile(sim_savings, [2.5, 97.5])
            means_savings.append(mean_sav)
            # yerr format: [[lower_error], [upper_error]] where error is distance from mean
            errs_savings.append([mean_sav - ci_sav[0], ci_sav[1] - mean_sav])

            # Carbon offset distributions
            sim_kwh = count * saved_power_kw * 24 * 365
            sim_carbon = (sim_kwh * sim_intensity) / 1000.0
            mean_carb = np.mean(sim_carbon)
            ci_carb = np.percentile(sim_carbon, [2.5, 97.5])
            means_carbon.append(mean_carb)
            errs_carbon.append([mean_carb - ci_carb[0], ci_carb[1] - mean_carb])

        # Convert error list to 2x3 array for yerr
        errs_sav_arr = np.array(errs_savings).T
        errs_carb_arr = np.array(errs_carbon).T

        # Plot bars with error bars representing 95% Confidence Intervals
        x_offset = x + (i - 1) * width
        ax1.bar(x_offset, means_savings, width, label=data['label'], color=data['color'], 
                yerr=errs_sav_arr, ecolor='#D1D5DB', capsize=4)
        ax2.bar(x_offset, means_carbon, width, label=data['label'], color=data['color'], 
                yerr=errs_carb_arr, ecolor='#D1D5DB', capsize=4)

    ax1.set_title('Annual Infrastructure Cost Savings (USD)', fontsize=13, fontweight='bold', pad=15)
    ax1.set_xticks(x)
    ax1.set_xticklabels(categories)
    ax1.set_yscale('log')
    ax1.set_ylabel('Savings (USD, Log Scale)')
    ax1.grid(True, linestyle='--', alpha=0.3)
    ax1.legend(frameon=True, facecolor='#1F2937', edgecolor='none')

    ax2.set_title(f'Annual Carbon Emissions Offset (kg CO2e @ {uk_intensity_mean:.0f} g/kWh)', fontsize=13, fontweight='bold', pad=15)
    ax2.set_xticks(x)
    ax2.set_xticklabels(categories)
    ax2.set_yscale('log')
    ax2.set_ylabel('CO2e Avoided (kg, Log Scale)')
    ax2.grid(True, linestyle='--', alpha=0.3)
    ax2.legend(frameon=True, facecolor='#1F2937', edgecolor='none')

    plt.suptitle('ROI of AI-Synthesized Thin-Stack Microservices (UK Grid Focus)\n95% Confidence Intervals via 10,000-Trial Monte Carlo', 
                 fontsize=15, fontweight='bold', y=0.99)
    plt.tight_layout()
    
    output_path = '/home/pr/vaults/writing/drafts/roi_chart.png'
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"Success: Chart saved to {output_path}")

if __name__ == '__main__':
    generate_charts()
