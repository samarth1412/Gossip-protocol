import argv
import boss
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/otp/actor
import node
import time_util
import topology

pub fn main() -> Nil {
  let args = argv.args()
  case args {
    [num_nodes_s, topo_s, algo_s] -> run_actor_model(num_nodes_s, topo_s, algo_s)
    _ -> io.println("Usage: project2 numNodes topology[full|3D|line|imp3D] algorithm[gossip|push-sum]")
  }
}

fn run_actor_model(num_nodes_s: String, topo_s: String, algo_s: String) -> Nil {
  let assert Ok(n) = int.parse(num_nodes_s)
  let assert Ok(topo) = topology.parse_topology(topo_s)
  let algo = case algo_s {
    "gossip" -> node.Gossip
    "push-sum" -> node.PushSum
    _ -> node.Gossip
  }

  // Start timing
  time_util.start_counters()
  
  // Start boss actor
  let assert Ok(actor.Started(data: boss_subject, ..)) = boss.start()
  
  // Create a reply subject for the boss to respond to
  let reply_subject = process.new_subject()
  
  // Send start message to boss with real actor model
  process.send(boss_subject, boss.Start(n, topo, algo, reply_subject))
  
  // Wait for convergence
  process.receive_forever(reply_subject)
  
  // Print timing results
  let ms = time_util.elapsed_ms()
  io.println("Convergence time (ms): " <> int.to_string(ms))
}
