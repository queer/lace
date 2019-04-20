defmodule Lace do
  use GenServer
  require Logger
  alias Lace.Redis

  @connect_interval 1000

  def start_link(opts) do
    GenServer.start_link __MODULE__, opts
  end

  def init(opts) do
    network_state = get_network_state()
    hash =
      :crypto.hash(:md5, :os.system_time(:millisecond) 
      |> Integer.to_string) 
      |> Base.encode16 
      |> String.downcase
    state = %{
      name: "#{opts[:name]}_#{network_state[:hostname]}_#{opts[:discrim] || hash}",
      group: opts[:group],
      cookie: opts[:cookie],
      longname: nil,
      hostname: network_state[:hostname],
      ip: network_state[:hostaddr],
      hash: hash,
    }
    
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
    else
      Logger.warn "lace: Node already alive, doing nothing..."
    end
    
    Process.send_after self(), :connect, 100
    {:ok, state}
  end

  def handle_info(:connect, state) do
    registry_write state
    nodes = registry_read state

    for node <- nodes do
      {hash, longname} = node

      unless hash == state[:hash] do
        case Node.connect(longname |> String.to_atom) do
          true ->
            # Logger.debug "Connected to #{longname}"
            nil
          false ->
            delete_node state, hash, longname
          :ignored ->
            # Logger.debug "[WARN] Local node not alive for #{longname}!?"
            nil
        end
      end
    end
    # Logger.debug "lace: Connected to: #{inspect Node.list}"

    Process.send_after self(), :connect, @connect_interval

    {:noreply, state}
  end

  defp delete_node(state, hash, longname) do
    # Logger.debug "[WARN] Couldn't connect to #{longname} (#{hash}), deleting..."
    reg = registry_name state[:group]
    {:ok, _} = Redis.q ["HDEL", reg, hash]
    :ok
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
    {:ok, res} = Redis.q ["HGETALL", reg]
    # Logger.debug "Reg: #{inspect reg}"
    # Logger.debug "Reg: #{inspect res}"
    res
    |> Enum.chunk(2)
    |> Enum.map(fn [a, b] -> {a, b} end)
    |> Enum.to_list
  end

  # Write ourself to the registry
  defp registry_write(state) do
    reg = registry_name state[:group]
    Redis.q ["HSET", reg, state[:hash], state[:longname]]
  end

  defp registry_name(name) do
    "lace:reg:#{name}"
  end
end
