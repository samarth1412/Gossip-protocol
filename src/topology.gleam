import gleam/list

pub type Topology {
  Full
  Line
  Grid3D
  Imp3D
}

pub fn parse_topology(s: String) {
  case s {
    "full" -> Ok(Full)
    "line" -> Ok(Line)
    "3D" -> Ok(Grid3D)
    "imp3D" -> Ok(Imp3D)
    _ -> Error("unknown topology: " <> s)
  }
}

pub fn neighbors(node: Int, total: Int, topo: Topology) -> List(Int) {
  case topo {
    Full ->
      list.range(0, total - 1)
      |> list.filter(fn(i) { i != node })
    Line -> line_neighbors(node, total)
    Grid3D -> grid3d_neighbors(node, total)
    Imp3D -> {
      let base = grid3d_neighbors(node, total)
      let extra = { node + 7 } % total
      case contains(base, extra) {
        True -> base
        False -> [extra, ..base]
      }
    }
  }
}

fn line_neighbors(node: Int, total: Int) -> List(Int) {
  let left = case node - 1 < 0 { True -> [] False -> [node - 1] }
  let right = case node + 1 >= total { True -> [] False -> [node + 1] }
  list.append(left, right)
}

fn cube_dim(total: Int) -> Int {
  // smallest d so that d^3 >= total
  smallest_dim_loop(1, total)
}

fn smallest_dim_loop(d: Int, total: Int) -> Int {
  case d * d * d >= total {
    True -> d
    False -> smallest_dim_loop(d + 1, total)
  }
}

fn grid3d_neighbors(node: Int, total: Int) -> List(Int) {
  let d = cube_dim(total)
  let x = node % d
  let y = { node / d } % d
  let z = node / { d * d }

  let left = case x - 1 >= 0 { True -> [idx(x - 1, y, z, d)] False -> [] }
  let right = case x + 1 < d { True -> [idx(x + 1, y, z, d)] False -> [] }
  let down = case y - 1 >= 0 { True -> [idx(x, y - 1, z, d)] False -> [] }
  let up = case y + 1 < d { True -> [idx(x, y + 1, z, d)] False -> [] }
  let back = case z - 1 >= 0 { True -> [idx(x, y, z - 1, d)] False -> [] }
  let front = case z + 1 < d { True -> [idx(x, y, z + 1, d)] False -> [] }

  let ns1 = list.append(left, right)
  let ns2 = list.append(ns1, down)
  let ns3 = list.append(ns2, up)
  let ns4 = list.append(ns3, back)
  let ns5 = list.append(ns4, front)
  ns5
  |> list.filter(fn(i) { i >= 0 && i < total })
}

fn contains(xs: List(Int), x: Int) -> Bool {
  case xs {
    [] -> False
    [h, ..t] -> case h == x { True -> True False -> contains(t, x) }
  }
}

fn idx(x: Int, y: Int, z: Int, d: Int) -> Int {
  x + y * d + z * d * d
}


