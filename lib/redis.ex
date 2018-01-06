defmodule Lace.Redis do
  @moduledoc """
  Redis pooling
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link __MODULE__, opts
  end

  def init(opts) do
    pool_options = [
      {:name, {:local, :redis_pool}},
      {:worker_module, :eredis}, 
      {:size, opts[:pool_size]},
      {:max_overflow, 10}
    ]
    eredis_args = [
      {:host, String.to_charlist(opts[:redis_ip])},
      {:port, opts[:redis_port]},
      {:password, String.to_charlist(opts[:redis_pass])}
    ]
    children = [
      :poolboy.child_spec(:redis_pool, pool_options, eredis_args)
    ]
    supervise(children, strategy: :one_for_one)
  end

  @doc """
  Run a single redis command
  """
  def q(args) do
    {:ok, _item} = :poolboy.transaction(:redis_pool, fn(worker) -> q(worker, args) end)
  end

  @doc """
  Run a single redis command against the specified worker
  """
  def q(worker, args) do
    {:ok, _item} = :eredis.q worker, args, 5000
  end

  @doc """
  Run a transaction. The function passed in must take a worker and should 
  ideally use q/2
  """
  def t(f) do
    :poolboy.transaction(:redis_pool, fn(worker) -> 
        q worker, ["MULTI"]
        f.(worker)
        q worker, ["EXEC"]
      end)
  end
end
