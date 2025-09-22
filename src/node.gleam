import gleam/erlang/process
import gleam/list
import gleam/option
import gleam/otp/actor

pub type Algo {
  Gossip
  PushSum
}

pub type NodeMsg {
  Init(neighbors: List(process.Subject(NodeMsg)), algo: Algo)
  Rumor
  Tick
  Push(pair_s: Float, pair_w: Float)
  GetTerminated(process.Subject(Bool))
}

pub type NodeState {
  NodeState(
    id: Int,
    neighbors: List(process.Subject(NodeMsg)),
    algo: Algo,
    rumor_count: Int,
    s: Float,
    w: Float,
    stable_rounds: Int,
    last_ratio: Float,
    done: Bool,
  )
}

pub fn start(
  id: Int,
  initial_value: Float,
) -> actor.StartResult(process.Subject(NodeMsg)) {
  let state = NodeState(
    id: id,
    neighbors: [],
    algo: Gossip,
    rumor_count: 0,
    s: initial_value,
    w: 1.0,
    stable_rounds: 0,
    last_ratio: initial_value /. 1.0,
    done: False,
  )

  actor.new(state)
  |> actor.on_message(handle)
  |> actor.start
}

fn handle(state: NodeState, msg: NodeMsg) -> actor.Next(NodeState, NodeMsg) {
  case state, msg {
    NodeState(done: True, ..), GetTerminated(reply) -> {
      process.send(reply, True)
      actor.continue(state)
    }
    NodeState(done: True, ..), _ -> actor.continue(state)
    NodeState(id, neighbors, algo, rumor_count, s, w, stable_rounds, last_ratio, done), Init(ns, al) -> {
      let new_state = NodeState(id, ns, al, rumor_count, s, w, stable_rounds, last_ratio, done)
      actor.continue(new_state)
    }
    NodeState(id, neighbors, Gossip, rumor_count, s, w, stable_rounds, last_ratio, done), Rumor -> {
      let new_count = rumor_count + 1
      let done_now = new_count >= 10
      let _ = case done_now { True -> Nil False -> send_random(neighbors, Rumor) }
      actor.continue(NodeState(id, neighbors, Gossip, new_count, s, w, stable_rounds, last_ratio, done_now))
    }
    NodeState(id, neighbors, Gossip, rumor_count, s, w, stable_rounds, last_ratio, done), Tick -> {
      let _ = case done || rumor_count == 0 { True -> Nil False -> send_random(neighbors, Rumor) }
      actor.continue(NodeState(id, neighbors, Gossip, rumor_count, s, w, stable_rounds, last_ratio, done))
    }
    NodeState(id, neighbors, PushSum, rumor_count, s, w, stable_rounds, last_ratio, done), Push(ps, pw) -> {
      let s1 = s +. ps
      let w1 = w +. pw
      let ratio = s1 /. w1
      let stable1 = case abs_float(ratio -. last_ratio) <. 1.0e-10 { True -> stable_rounds + 1 False -> 0 }
      let done_now = stable1 >= 3

      // split in half and send
      let send_s = s1 /. 2.0
      let send_w = w1 /. 2.0
      let keep_s = s1 -. send_s
      let keep_w = w1 -. send_w

      let _ = send_random(neighbors, Push(send_s, send_w))

      actor.continue(NodeState(id, neighbors, PushSum, rumor_count, keep_s, keep_w, stable1, ratio, done_now))
    }
    NodeState(id, neighbors, PushSum, rumor_count, s, w, stable_rounds, last_ratio, done), Rumor -> actor.continue(state)
    NodeState(id, neighbors, PushSum, rumor_count, s, w, stable_rounds, last_ratio, done), Tick -> actor.continue(state)
    NodeState(id, neighbors, Gossip, rumor_count, s, w, stable_rounds, last_ratio, done), Push(_, _) -> actor.continue(state)
    NodeState(id, neighbors, algo, rumor_count, s, w, stable_rounds, last_ratio, done), GetTerminated(reply) -> {
      process.send(reply, done)
      actor.continue(state)
    }
  }
}

fn abs_float(x: Float) -> Float {
  case x <. 0.0 { True -> 0.0 -. x False -> x }
}

fn send_random(neighbors: List(process.Subject(NodeMsg)), msg: NodeMsg) -> Nil {
  case pick_neighbor(neighbors) {
    option.Some(to) -> process.send(to, msg)
    option.None -> Nil
  }
}


fn pick_neighbor(neighbors: List(process.Subject(NodeMsg))) -> option.Option(process.Subject(NodeMsg)) {
  case neighbors {
    [] -> option.None
    _ -> {
      let size = list.length(neighbors)
      let idx = pseudo_rand(size)
      option.Some(subject_at(neighbors, idx))
    }
  }
}

fn subject_at(xs: List(process.Subject(NodeMsg)), index: Int) -> process.Subject(NodeMsg) {
  subject_at_loop(xs, index, 0)
}

fn subject_at_loop(
  xs: List(process.Subject(NodeMsg)),
  index: Int,
  i: Int,
) -> process.Subject(NodeMsg) {
  case xs {
    [h, ..t] -> case i == index { True -> h False -> subject_at_loop(t, index, i + 1) }
    [] -> process.new_subject()
  }
}

fn pseudo_rand(n: Int) -> Int {
  // Simple time-based value; good enough for simulation
  let t = monotonic_time()
  case n <= 0 { True -> 0 False -> { t % 2147483647 } % n }
}

@external(erlang, "erlang", "monotonic_time")
fn monotonic_time() -> Int


