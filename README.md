# Project 2: Gossip Protocol Implementation

A Gleam implementation of gossip and push-sum algorithms for distributed systems simulation.

## Team Members
- Samarth (samarth1412)

## What is Working

### ✅ Implemented Features
- **Gossip Algorithm**: Nodes spread rumors until hearing them 10 times, then terminate
- **Push-Sum Algorithm**: Nodes compute distributed sum with convergence when ratio stabilizes (3 consecutive rounds within 10^-10)
- **All Required Topologies**:
  - `full`: Every node connects to every other node
  - `line`: Nodes arranged in a line with left/right neighbors
  - `3D`: 3D grid topology with up to 6 neighbors per node
  - `imp3D`: Imperfect 3D grid with one additional random neighbor
- **Timing**: Convergence time measurement using wall-clock time
- **Actor Model**: Simple simulation without complex actor framework

### ✅ Command Line Interface
```bash
gleam run -m project2_gossip <numNodes> <topology> <algorithm>
```

Where:
- `numNodes`: Number of actors/nodes (e.g., 10, 50, 100)
- `topology`: One of `full`, `line`, `3D`, `imp3D`
- `algorithm`: One of `gossip`, `push-sum`

## Usage Examples

```bash
# Gossip on full network with 10 nodes
gleam run -m project2_gossip 10 full gossip

# Push-sum on line topology with 20 nodes
gleam run -m project2_gossip 20 line push-sum

# 3D grid gossip with 50 nodes
gleam run -m project2_gossip 50 3D gossip

# Imperfect 3D grid push-sum with 30 nodes
gleam run -m project2_gossip 30 imp3D push-sum
```

## Setup & Installation

1. **Install Gleam**: Follow [official installation guide](https://gleam.run/getting-started/installing/)
2. **Clone/Download**: Ensure you have the project files
3. **Build**: `gleam build`
4. **Run**: Use examples above

## Largest Networks Tested

- **Full Topology**: Up to 100 nodes for both algorithms
- **Line Topology**: Up to 50 nodes (convergence slower due to limited connectivity)
- **3D Grid**: Up to 125 nodes (5×5×5 cube)
- **Imperfect 3D**: Up to 100 nodes (improved connectivity vs regular 3D)

## Performance Observations

- **Full topology** converges fastest due to maximum connectivity
- **Line topology** is slowest, especially for push-sum
- **3D grid** provides good balance of connectivity and scalability
- **Imperfect 3D** improves convergence time over regular 3D due to additional random connections

## Implementation Notes

- Uses simplified simulation approach rather than complex actor framework
- Deterministic neighbor selection for consistent results
- Timeout protection prevents infinite loops (max 1000 rounds)
- Wall-clock timing for convergence measurement
- All topologies handle edge cases (boundary nodes, isolated nodes)

## Algorithm Details

### Gossip
1. One node receives initial rumor
2. Nodes with rumors spread to random neighbors each round
3. Node terminates after hearing rumor 10 times
4. Convergence when all nodes terminated

### Push-Sum
1. Each node starts with value equal to its ID+1, weight=1
2. One node receives initial push (0,0)
3. Each round, active nodes send half their (s,w) to random neighbor
4. Node terminates when s/w ratio stable for 3 consecutive rounds (change < 10^-10)
5. Convergence when all nodes terminated

## Files Structure

- `src/simple_gossip.gleam` - Main implementation with both algorithms
- `src/topology.gleam` - Network topology generation
- `src/time_util.gleam` - Timing utilities
- `src/argv.gleam` - Command line argument parsing
- `src/project2_gossip.gleam` - Entry point