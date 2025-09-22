import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/otp/actor
import node
import topology

pub type BossMsg {
  Start(num_nodes: Int, topo: topology.Topology, algo: node.Algo, reply: process.Subject(Nil))
}

pub fn start() -> actor.StartResult(process.Subject(BossMsg)) {
  actor.new(Nil)
  |> actor.on_message(handle)
  |> actor.start
}

fn handle(state: Nil, msg: BossMsg) -> actor.Next(Nil, BossMsg) {
  case msg {
    Start(num_nodes, topo, algo, reply) -> {
      // Create delivery mailbox for node-to-node messages
      let _mailbox = process.new_subject()

      // Spawn nodes
      let nodes =
        list.range(0, num_nodes - 1)
        |> list.map(fn(i) {
          let assert Ok(actor.Started(data: sub, ..)) = node.start(i, int.to_float(i + 1))
          sub
        })

      // Wire neighbors
      nodes
      |> list.index_map(fn(_nsub, i) {
        let idxs = topology.neighbors(i, num_nodes, topo)
        let ns = idxs |> list.map(fn(j) { subject_at(nodes, j) })
        process.send(subject_at(nodes, i), node.Init(ns, algo))
      })

      // Seed start
      case algo {
        node.Gossip -> {
          process.send(subject_at(nodes, 0), node.Rumor)
          process.send(subject_at(nodes, 0), node.Tick)
        }
        node.PushSum -> process.send(subject_at(nodes, 0), node.Push(0.0, 0.0))
      }

      // Pump messages until convergence: when all nodes terminated
      convergence_loop(nodes, algo)

      process.send(reply, Nil)
      actor.continue(state)
    }
  }
}

fn convergence_loop(nodes: List(process.Subject(node.NodeMsg)), algo: node.Algo) -> Nil {
  let done_probe = process.new_subject()
  convergence_step(nodes, algo, done_probe)
}

fn convergence_step(
  nodes: List(process.Subject(node.NodeMsg)),
  algo: node.Algo,
  done_probe: process.Subject(Bool),
) -> Nil {
  convergence_loop_with_timeout(nodes, algo, done_probe, 0)
}

fn convergence_loop_with_timeout(
  nodes: List(process.Subject(node.NodeMsg)),
  algo: node.Algo,
  done_probe: process.Subject(Bool),
  iterations: Int,
) -> Nil {
  // Prevent infinite loops with a timeout
  case iterations > 1000 {
    True -> Nil
    False -> {
      // Drive the protocol forward (scheduler ticks for gossip)
      case algo {
        node.Gossip -> nodes |> list.each(fn(s) { process.send(s, node.Tick) })
        node.PushSum -> Nil
      }

      // Check terminations occasionally
      let remaining =
        list.range(0, list.length(nodes) - 1)
        |> list.map(fn(i) {
          let sub = subject_at(nodes, i)
          process.send(sub, node.GetTerminated(done_probe))
          process.receive_forever(done_probe)
        })
        |> list.filter(fn(b) { b == False })
        |> list.length

      case remaining > 0 {
        True -> convergence_loop_with_timeout(nodes, algo, done_probe, iterations + 1)
        False -> Nil
      }
    }
  }
}

fn subject_at(xs: List(process.Subject(node.NodeMsg)), index: Int) -> process.Subject(node.NodeMsg) {
  subject_at_loop(xs, index, 0)
}

fn subject_at_loop(
  xs: List(process.Subject(node.NodeMsg)),
  index: Int,
  i: Int,
) -> process.Subject(node.NodeMsg) {
  case xs {
    [h, ..t] -> case i == index { True -> h False -> subject_at_loop(t, index, i + 1) }
    [] -> process.new_subject()
  }
}


