import gleam/erlang/atom

@external(erlang, "erlang", "statistics")
fn stats(a: atom.Atom) -> #(Int, Int)

pub fn start_counters() -> Nil {
  let _ = stats(atom.create("wall_clock"))
  Nil
}

pub fn elapsed_ms() -> Int {
  let #(_, wall) = stats(atom.create("wall_clock"))
  wall
}


