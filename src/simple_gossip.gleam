import argv
import gleam/int
import gleam/io
import gleam/list
import time_util
import topology

pub type Algorithm {
  Gossip
  PushSum
}

pub type Node {
  Node(
    id: Int,
    neighbors: List(Int),
    rumor_count: Int,
    s: Float,
    w: Float,
    stable_rounds: Int,
    last_ratio: Float,
    terminated: Bool,
  )
}

pub fn main() -> Nil {
  let args = argv.args()
  case args {
    [num_nodes_s, topo_s, algo_s] -> run(num_nodes_s, topo_s, algo_s)
    _ -> io.println("Usage: project2 numNodes topology[full|3D|line|imp3D] algorithm[gossip|push-sum]")
  }
}

fn run(num_nodes_s: String, topo_s: String, algo_s: String) -> Nil {
  let assert Ok(n) = int.parse(num_nodes_s)
  let assert Ok(topo) = topology.parse_topology(topo_s)
  let algo = case algo_s {
    "gossip" -> Gossip
    "push-sum" -> PushSum
    _ -> Gossip
  }

  time_util.start_counters()
  
  // Create nodes
  let nodes = 
    list.range(0, n - 1)
    |> list.map(fn(i) {
      let ns = topology.neighbors(i, n, topo)
      Node(
        id: i,
        neighbors: ns,
        rumor_count: 0,
        s: int.to_float(i + 1),
        w: 1.0,
        stable_rounds: 0,
        last_ratio: int.to_float(i + 1),
        terminated: False,
      )
    })

  // Run simulation
  let final_nodes = case algo {
    Gossip -> simulate_gossip(nodes, 0)
    PushSum -> simulate_push_sum(nodes)
  }

  let ms = time_util.elapsed_ms()
  io.println("Convergence time (ms): " <> int.to_string(ms))
}

fn simulate_gossip(nodes: List(Node), seed_node: Int) -> List(Node) {
  // Start gossip at seed node
  let updated = update_node_rumor(nodes, seed_node)
  gossip_rounds(updated, 0)
}

fn gossip_rounds(nodes: List(Node), round: Int) -> List(Node) {
  case round > 1000 || all_terminated_gossip(nodes) {
    True -> nodes
    False -> {
      // Collect all rumors to spread this round
      let rumors_to_spread = collect_rumors_to_spread(nodes, [])
      // Apply all rumors at once
      let new_nodes = apply_rumors(nodes, rumors_to_spread)
      gossip_rounds(new_nodes, round + 1)
    }
  }
}

fn collect_rumors_to_spread(nodes: List(Node), acc: List(Int)) -> List(Int) {
  case nodes {
    [] -> acc
    [node, ..rest] -> {
      case node.rumor_count > 0 && node.rumor_count < 10 && not_empty(node.neighbors) {
        True -> {
          let target = pick_random_neighbor(node.neighbors)
          collect_rumors_to_spread(rest, [target, ..acc])
        }
        False -> collect_rumors_to_spread(rest, acc)
      }
    }
  }
}

fn apply_rumors(nodes: List(Node), targets: List(Int)) -> List(Node) {
  case targets {
    [] -> nodes
    [target, ..rest] -> {
      let updated_nodes = update_node_rumor(nodes, target)
      apply_rumors(updated_nodes, rest)
    }
  }
}

fn simulate_push_sum(nodes: List(Node)) -> List(Node) {
  // Start push-sum at node 0
  let initial = update_node_push(nodes, 0, 0.0, 0.0)
  push_sum_rounds(initial, 0)
}

fn push_sum_rounds(nodes: List(Node), round: Int) -> List(Node) {
  case round > 1000 || all_terminated_push_sum(nodes) {
    True -> nodes
    False -> {
      // Collect all push messages to send this round
      let pushes_to_send = collect_pushes_to_send(nodes, [], 0)
      // Apply all push operations
      let new_nodes = apply_pushes(nodes, pushes_to_send)
      push_sum_rounds(new_nodes, round + 1)
    }
  }
}

pub type PushMessage {
  PushMessage(from: Int, to: Int, s: Float, w: Float)
}

fn collect_pushes_to_send(nodes: List(Node), acc: List(PushMessage), index: Int) -> List(PushMessage) {
  case nodes {
    [] -> acc
    [node, ..rest] -> {
      case not_terminated_push(node) && not_empty(node.neighbors) {
        True -> {
          let target = pick_random_neighbor(node.neighbors)
          let send_s = node.s /. 2.0
          let send_w = node.w /. 2.0
          let push_msg = PushMessage(from: index, to: target, s: send_s, w: send_w)
          collect_pushes_to_send(rest, [push_msg, ..acc], index + 1)
        }
        False -> collect_pushes_to_send(rest, acc, index + 1)
      }
    }
  }
}

fn apply_pushes(nodes: List(Node), pushes: List(PushMessage)) -> List(Node) {
  // First, halve all sending nodes' values
  let updated_nodes = apply_sending_halvings(nodes, pushes, 0)
  // Then, apply all received values
  apply_received_values(updated_nodes, pushes)
}

fn apply_sending_halvings(nodes: List(Node), pushes: List(PushMessage), index: Int) -> List(Node) {
  case nodes {
    [] -> []
    [node, ..rest] -> {
      let should_halve = list.any(pushes, fn(push) { push.from == index })
      case should_halve {
        True -> [Node(..node, s: node.s /. 2.0, w: node.w /. 2.0), ..apply_sending_halvings(rest, pushes, index + 1)]
        False -> [node, ..apply_sending_halvings(rest, pushes, index + 1)]
      }
    }
  }
}

fn apply_received_values(nodes: List(Node), pushes: List(PushMessage)) -> List(Node) {
  case pushes {
    [] -> nodes
    [push, ..rest] -> {
      let updated_nodes = update_node_push(nodes, push.to, push.s, push.w)
      apply_received_values(updated_nodes, rest)
    }
  }
}

fn update_node_rumor(nodes: List(Node), target: Int) -> List(Node) {
  nodes
  |> list.index_map(fn(node, i) {
    case i == target {
      True -> {
        let new_count = node.rumor_count + 1
        Node(..node, rumor_count: new_count, terminated: new_count >= 10)
      }
      False -> node
    }
  })
}

fn spread_rumor_to(nodes: List(Node), target: Int) -> List(Node) {
  update_node_rumor(nodes, target)
}

fn update_node_push(nodes: List(Node), target: Int, recv_s: Float, recv_w: Float) -> List(Node) {
  nodes
  |> list.index_map(fn(node, i) {
    case i == target {
      True -> {
        let new_s = node.s +. recv_s
        let new_w = node.w +. recv_w
        let new_ratio = new_s /. new_w
        let stable = case abs_diff(new_ratio, node.last_ratio) <. 1.0e-10 {
          True -> node.stable_rounds + 1
          False -> 0
        }
        Node(..node, s: new_s, w: new_w, last_ratio: new_ratio, stable_rounds: stable, terminated: stable >= 3)
      }
      False -> node
    }
  })
}

fn all_terminated_gossip(nodes: List(Node)) -> Bool {
  nodes |> list.all(fn(n) { n.terminated })
}

fn all_terminated_push_sum(nodes: List(Node)) -> Bool {
  nodes |> list.all(fn(n) { n.terminated })
}

fn not_terminated_push(node: Node) -> Bool {
  !node.terminated
}

fn not_empty(xs: List(a)) -> Bool {
  case xs { [] -> False _ -> True }
}

fn pick_random_neighbor(neighbors: List(Int)) -> Int {
  let size = list.length(neighbors)
  let idx = simple_rand(size)
  nth_element(neighbors, idx)
}

fn simple_rand(n: Int) -> Int {
  case n <= 0 { 
    True -> 0 
    False -> {
      // Use time-based randomization for better distribution
      let t = get_monotonic_time()
      let hash = { t * 1103515245 + 12345 } % 2147483647
      case hash < 0 { True -> -hash % n False -> hash % n }
    }
  }
}

fn abs_diff(a: Float, b: Float) -> Float {
  case a >. b { True -> a -. b False -> b -. a }
}

fn update_at(xs: List(a), index: Int, value: a) -> List(a) {
  xs |> list.index_map(fn(x, i) { case i == index { True -> value False -> x } })
}

fn unwrap_or(result: Result(a, b), default: a) -> a {
  case result { Ok(val) -> val Error(_) -> default }
}

fn nth_element(xs: List(Int), idx: Int) -> Int {
  nth_element_loop(xs, idx, 0)
}

fn nth_element_loop(xs: List(Int), idx: Int, i: Int) -> Int {
  case xs {
    [h, ..t] -> case i == idx { True -> h False -> nth_element_loop(t, idx, i + 1) }
    [] -> 0
  }
}

@external(erlang, "erlang", "monotonic_time")
fn get_monotonic_time() -> Int
