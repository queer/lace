defmodule Lace do
  use GenServer
  require Logger

  @connect_interval 1000

  def start_link(_) do
    GenServer.start_link __MODULE__, :ok
  end

  def init(_) do
    {:ok, redis} = Redix.start_link(System.get_env("REDIS_URL"))
    network_state = get_network_state()
    state = %{
      name: System.get_env("NAME"),
      group: System.get_env("GROUP"),
      cookie: System.get_env("COOKIE"),
      longname: nil,
      hostname: network_state[:hostname],
      ip: network_state[:hostaddr],
      redis: redis,
    }
    Process.send_after self(), :start_connect, 250
    {:ok, state}
  end

  def handle_info(:start_connect, state) do
    unless Node.alive? do
      node_name = "#{state[:name]}@#{state[:ip]}"
      node_atom = node_name |> String.to_atom

      Logger.info "lace: Starting node: #{node_name}"
      {:ok, _} = Node.start(node_atom, :longnames)
      Node.set_cookie(state[:cookie] |> String.to_atom)

      Logger.info "Updating registry..."
      new_state = %{state | longname: node_name}
      registry_write new_state

      Logger.info "All done! Starting lace..."
      Process.send_after self(), :connect, 250

      {:noreply, new_state}
    else
      Logger.warn "lace: Node already alive, doing nothing..."
      {:noreply, state}
    end
  end

  def handle_info(:connect, state) do
    registry_write state
    nodes = registry_read state

    for node <- nodes do
      {hostname, longname} = node

      case Node.connect(longname |> String.to_atom) do
        true -> Logger.info "Connected to #{longname}"
        false -> Logger.warn "Couldn't connect to #{longname}"
        :ignored -> Logger.warn "Local node not alive for #{longname}!?"
      end
    end
    Logger.info "lace: Connected to: #{inspect Node.list}"

    Process.send_after self(), :connect, @connect_interval

    {:noreply, state}
  end

  defp get_network_state do
    {:ok, hostname} = :inet.gethostname()
    {:ok, hostaddr} = :inet.getaddr(hostname, :inet)
    %{
      hostname: to_string(hostname), 
      hostaddr: (hostaddr |> Tuple.to_list |> Enum.join("."))
    }
  end

  # Read all members of the registry
  defp registry_read(state) do
    reg = registry_name state[:group]
    {:ok, res} = Redix.command state[:redis], ["HGETALL", reg]

    res
    |> Enum.chunk(2)
    |> Enum.map(fn [a, b] -> {a, b} end)
    |> Enum.to_list
  end

  # Write ourself to the registry
  defp registry_write(state) do
    reg = registry_name state[:group]
    Redix.command state[:redis], ["HSET", reg, state[:hostname], state[:longname]]
  end

  defp registry_name(name) do
    "lace-reg-#{name}"
  end
end
