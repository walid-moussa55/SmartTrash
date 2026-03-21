from geopy.distance import geodesic
from typing import List, Dict, Tuple
import json
import heapq

def calculate_distances(bins: List[Dict], container: Dict) -> Dict[Tuple, float]:
    """
    Calculate distances between all bins and container using geopy
    Returns dictionary with (point1, point2) tuples as keys and distances as values
    """
    distances = {}
    all_points = bins + [container]
    
    for i, point1 in enumerate(all_points):
        for point2 in all_points[i+1:]:
            coord1 = (point1['location']['latitude'], point1['location']['longitude'])
            coord2 = (point2['location']['latitude'], point2['location']['longitude'])
            distance = geodesic(coord1, coord2).kilometers
            distances[(point1['name'], point2['name'])] = distance
            distances[(point2['name'], point1['name'])] = distance
            
    return distances

def get_neighbors(point: str, distances: Dict[Tuple, float], max_distance: float) -> List[Tuple[str, float]]:
    """
    Get all neighbors within max_distance for a given point
    Returns list of (neighbor_name, distance) tuples
    """
    neighbors = []
    for (point1, point2), distance in distances.items():
        if point1 == point:
            if distance <= max_distance:
                neighbors.append((point2, distance))
    return neighbors

def shortest_path(start: str, targets: List[str], distances: Dict[Tuple, float]) -> Tuple[List[str], float]:
    """
    Find shortest path to cover all target points using Dijkstra's algorithm
    Returns (path, total_distance)
    """
    def dijkstra(start: str, end: str) -> Tuple[List[str], float]:
        queue = [(0, start, [start])]
        visited = set()
        
        while queue:
            (cost, current, path) = heapq.heappop(queue)
            if current == end:
                return (path, cost)
                
            if current not in visited:
                visited.add(current)
                for neighbor, distance in get_neighbors(current, distances, float('inf')):
                    if neighbor not in visited:
                        heapq.heappush(queue, (cost + distance, neighbor, path + [neighbor]))
        return ([], float('inf'))

    current = start
    path = [current]
    total_distance = 0
    remaining_targets = set(targets)
    
    while remaining_targets:
        next_target = None
        min_distance = float('inf')
        min_path = []
        
        for target in remaining_targets:
            tmp_path, distance = dijkstra(current, target)
            if distance < min_distance:
                min_distance = distance
                next_target = target
                min_path = tmp_path
        
        if next_target:
            path.extend(min_path[1:])  # Exclude the current point
            total_distance += min_distance
            current = next_target
            remaining_targets.remove(next_target)
        else:
            break
            
    return path, total_distance

def select_bins_by_volume_and_weight(bins: List[Dict], container_volume: float, container_weight: float) -> List[Dict]:
    """
    Select bins based on volume, weight constraints and priority
    Returns sorted bins considering volume, weight and fullness priority
    """
    def priority_score(bin):
        capacity_weight = 0.6  # 60% weight to fullness
        volume_weight = 0.2    # 20% weight to volume
        weight_weight = 0.4    # 20% weight to weight
        
        fullness = bin['capacity'] / 100
        waste_volume = bin['volume'] * (bin['capacity'] / 100)
        waste_weight = bin['weight'] * (bin['capacity'] / 100)
        
        # Normalize values
        max_possible_volume = max(b['volume'] for b in bins)
        max_possible_weight = max(b['weight'] for b in bins)
        
        normalized_volume = waste_volume / max_possible_volume
        normalized_weight = waste_weight / max_possible_weight
        
        return (fullness * capacity_weight) + \
               (normalized_volume * volume_weight) + \
               (normalized_weight * weight_weight)
    
    # Sort bins by combined priority score
    sorted_bins = sorted(bins, key=priority_score, reverse=True)
    
    selected_bins = []
    current_volume = 0
    current_weight = 0
    
    for bin in sorted_bins:
        bin_waste_volume = bin['volume'] * (bin['capacity'] / 100)
        bin_waste_weight = bin['weight'] * (bin['capacity'] / 100)
        
        if (current_volume + bin_waste_volume <= container_volume and 
            current_weight + bin_waste_weight <= container_weight):
            selected_bins.append(bin)
            current_volume += bin_waste_volume
            current_weight += bin_waste_weight
            
    return selected_bins

def optimize_waste_collection(data: Dict) -> Tuple[List[Dict], float, float]:
    """
    Main function to optimize waste collection route
    Args:
        data: Dictionary containing container and bins information
    Returns:
        Tuple[List[Dict], float, float]: (ordered list of bins, total volume, total weight)
    """
    container = data['container']
    bins = data['bins']
    container_volume = container['volume']
    container_weight = container['weight']
    
    # Select bins based on volume and weight
    selected_bins = select_bins_by_volume_and_weight(bins, container_volume, container_weight)
    
    # Calculate distances
    distances = calculate_distances(selected_bins, container)
    
    # Get optimal path
    bin_names = [bin['name'] for bin in selected_bins]
    path, total_distance = shortest_path(container['name'], bin_names, distances)
    
    # Create final ordered list
    ordered_bins = []
    for name in path[1:]:  # Exclude container from path
        for bin in selected_bins:
            if bin['name'] == name:
                # add distance to bin
                bin['distance'] = distances[(container['name'], bin['name'])]
                ordered_bins.append(bin)
                break
    
    # Calculate total volume and weight to collect
    total_volume = sum(bin['volume'] * (bin['capacity'] / 100) for bin in ordered_bins)
    total_weight = sum(bin['weight'] * (bin['capacity'] / 100) for bin in ordered_bins)
    
    return ordered_bins, total_volume, total_weight
