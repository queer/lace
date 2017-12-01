# Lace

**TODO: Add description**

## Installation

Add the following to your `mix.exs`:

```elixir
def deps do
  [
    {:lace, github: "queer/lace"}
  ]
end
```

## Usage

Add the following to your application's supervision tree:

```elixir
children = [
  supervisor(Lace.Redis, %{redis_ip: "127.0.0.1", redis_port: 6379, pool_size: 10, redis_pass: "a"}),
  worker(Lace, %{name: "node_name", group: "group_name", cookie: "node_cookie"}),
]
```