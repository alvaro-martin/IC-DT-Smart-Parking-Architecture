# IC2 Parking Behavior Simulator

A Monte Carlo simulation tool for analyzing parking lot occupancy behavior at the IC2 building, UNICAMP. Built with Streamlit for interactive visualization and optional LLM-powered natural language control.

## Overview

This simulator predicts parking occupancy patterns based on historical arrival and dwell time data. It supports:

- **Manual simulation** with configurable parameters
- **LLM chat mode** for natural language parameter extraction
- **Confidence and prediction intervals** analysis
- **Probability of full parking** calculations

## Directory Structure

```
simulation/
├── app.py                          # Streamlit web application
├── llm_client.py                   # LLM client for natural language processing
├── simulator_runner.py             # Simulation execution and plotting functions
├── Dockerfile                      # Container configuration
├── requirements.txt                # Python dependencies
├── data/                           # Input data files
│   ├── arrival_per_5min_bin.csv    # Historical arrival rates per 5-min bin
│   ├── dwell_per_5min_bin.csv      # Historical dwell times per 5-min bin
│   └── occupied_mean_spots_5min.csv # Real occupancy data for validation
└── scripts/                        # Simulation scripts
    ├── montecarlo_simulation_with_rates_time_range.py
    ├── confidence_intervals_per_bin.py
    ├── prediction_interval_per_bin.py
    ├── full_spots_probability.py
    └── prob_k_free_spots.py
```

## Usage

### Run with Docker

```bash
docker compose -f simulation.yml up -d
```

Access the UI at `http://localhost:8501`

## Simulation Modes

### Manual Mode

Configure parameters through the UI:
- **Number of spots**: Total parking capacity (default: 16)
- **Number of simulations**: Monte Carlo iterations (default: 1000)
- **Percent arrivals**: Adjust arrival rate (-100% to +200%)
- **Percent dwell time**: Adjust dwell time (-100% to +200%)
- **Time window**: Apply modifications only to specific hours
- **Prediction interval**: Confidence level for intervals (50-99%)

### LLM Chat Mode

Interact with the simulator using natural language:
- "Run the simulation with 14 spots"
- "Increase arrivals by 20%"
- "From 12:00 to 16:00 arrivals decrease by 10%"
- "Run 5000 simulations"

The LLM extracts parameters from your message and runs the simulation automatically.

## Output Visualizations

1. **Simulated vs Real Occupancy**: Compares simulated results with historical data
2. **Confidence & Prediction Intervals**: Shows statistical uncertainty bands
3. **Probability of Full Parking**: Likelihood of all spots being occupied

## Environment Variables

<table>
<tr><th>Variable</th><th>Description</th><th>Required</th></tr>
<tr><td><code>API_URL</code></td><td>LLM API endpoint URL</td><td>No (disables LLM mode if not set)</td></tr>
<tr><td><code>API_KEY</code></td><td>LLM API authentication key</td><td>No (disables LLM mode if not set)</td></tr>
<tr><td><code>LLM_MODEL</code></td><td>LLM model name</td><td>No (default: deepseek-r1:1.5b)</td></tr>
</table>

## Dependencies

- Python 3.10+
- Streamlit
- Pandas
- Matplotlib
- NumPy
