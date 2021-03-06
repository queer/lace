# Lace

Redis-backed Erlang node clustering.

- [x] Node autodiscovery
- [x] Redis persistence
- [x] Autoprune unreachable nodes

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
  {Lace.Redis, %{redis_ip: "127.0.0.1", redis_port: 6379, pool_size: 10, redis_pass: "a"}},
  {Lace, %{name: "node_name", group: "group_name", cookie: "node_cookie"}},
]
```