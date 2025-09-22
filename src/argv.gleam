import gleam/erlang/charlist
import gleam/list

pub fn args() -> List(String) {
  get_plain_arguments()
  |> list.map(charlist.to_string)
}

@external(erlang, "init", "get_plain_arguments")
fn get_plain_arguments() -> List(charlist.Charlist)



