from collections import defaultdict
from datetime import datetime

def get_population_by_bin(data):
    counts = defaultdict(int)
    for record in data:
        bin_id = record.get("bin_id")
        if bin_id:
            counts[bin_id] += 1
    return dict(counts)

def get_bin_usage_by_region(data):
    usage = defaultdict(lambda: defaultdict(int))
    for record in data:
        region = record.get("region")
        bin_id = record.get("bin_id")
        if region and bin_id:
            usage[region][bin_id] += 1
    return usage

def get_trash_weight_correlation(data):
    correlation = []
    for record in data:
        trash_level = record.get("trash_level")
        weight = record.get("weight")
        if trash_level is not None and weight is not None:
            correlation.append({"x": trash_level, "y": weight})
    return correlation

def get_population_by_region(data):
    region_counts = defaultdict(int)
    for record in data:
        region = record.get("region")
        if region:
            region_counts[region] += 1
    return dict(region_counts)

def get_fill_rate_by_bin(data):
    # ✅ Correction ici : timestamp est déjà un objet datetime
    data = sorted(data, key=lambda x: (x['bin_id'], x['timestamp']))
    rates = {}
    last_seen = {}

    for entry in data:
        bin_id = entry.get("bin_id")
        trash_level = entry.get("trash_level")
        timestamp = entry.get("timestamp")  # déjà un datetime

        if bin_id and trash_level is not None and timestamp:
            if bin_id in last_seen:
                prev_time, prev_level = last_seen[bin_id]
                time_diff = (timestamp - prev_time).total_seconds() / 3600  # durée en heures
                level_diff = trash_level - prev_level

                if time_diff > 0:
                    rate = level_diff / time_diff
                    if bin_id not in rates:
                        rates[bin_id] = []
                    rates[bin_id].append(rate)

            last_seen[bin_id] = (timestamp, trash_level)

    avg_rates = {bin_id: round(sum(r) / len(r), 2) for bin_id, r in rates.items() if r}
    return avg_rates


