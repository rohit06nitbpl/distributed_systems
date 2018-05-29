defmodule GossipSimulator.GossiperManager do
  use GenServer
  @moduledoc """
  """
  
  ## Client API

  @doc """
  """
  @name GossipSimulator.GossiperManager
  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  @doc """
  """
  def lookup(index) do
    GenServer.call(@name, {:lookup, index})
  end
  
  def lookup_pairs(keys) do
    GenServer.call(@name, {:lookup_pairs, keys})
  end

  def report_infection(msg) do
    GenServer.cast(@name, {:report_infection, msg})
  end

  def report_push_sum_convergence(node, time) do
    GenServer.cast(@name, {:report_push_sum_convergence, node, time})
  end

  def set_start_time do
    GenServer.cast(@name, {:set_start_time})
  end

  def get_gossipers_count do
    GenServer.call(@name, {:get_gossipers_count})
  end
  
  def start_gossip(numNodes, topology, algorithm, msg \\ []) do
    {topology_name, neighbors} = topology
    add_gossipers(numNodes)
    set_topology(topology_name,numNodes)
    set_start_time
    {:ok,first_node} = lookup(0)
    GossipSimulator.Gossiper.gossip(first_node,algorithm,msg,10,neighbors)
  end
  

  @doc """
  """
  def add_gossipers(count) do
    if count > 0 do
      GenServer.cast(@name, {:add_gossipers})
      add_gossipers(count-1)
    end
  end

  def set_topology(topology, count, index \\ 0) do
    if count-index > 0 do
      set_neighbors(topology,count,index)
      set_topology(topology,count,index+1)
    end
  end
  
  def set_neighbors(topology,count,index) do
    case topology do
      :full   -> set_full_neighborhood(count,index)
      :grid2d -> set_2d_neighborhood(count,index)
      :line   -> set_line_neighborhood(count,index)
      :imp2d  -> set_imp2d_neighborhood(count,index)
    end
  end

  defp set_full_neighborhood(count,index) do
    range = 0..count-1
    filtered_index_list = Enum.filter(range, fn(x) -> if x != index do x end end)
    neighbors_list = lookup_pairs(filtered_index_list)
    neighbors_list = Map.to_list(neighbors_list)
    #IO.inspect neighbors_list
    GossipSimulator.Gossiper.set_neighbors(elem(lookup(index),1),neighbors_list)
  end

  defp set_2d_neighborhood(count,index) do
    filtered_index_list = grid_filter(count,index)
    neighbors_list = lookup_pairs(filtered_index_list)
    neighbors_list = Map.to_list(neighbors_list)
    #IO.inspect neighbors_list
    GossipSimulator.Gossiper.set_neighbors(elem(lookup(index),1),neighbors_list)
  end

  defp set_line_neighborhood(count,index) do
    filtered_index_list = [index-1,index+1]
    neighbors_list = lookup_pairs(filtered_index_list)
    neighbors_list = Map.to_list(neighbors_list)
    #IO.inspect neighbors_list
    GossipSimulator.Gossiper.set_neighbors(elem(lookup(index),1),neighbors_list)
  end
  
  defp set_imp2d_neighborhood(count,index) do
    filtered_index_list = grid_filter(count,index)
    range = Enum.map(0..count-1,fn x -> x end)
    complementry_index_list = range -- filtered_index_list -- [index]
    filtered_index_list = filtered_index_list ++ [Enum.random(complementry_index_list)]
    neighbors_list = lookup_pairs(filtered_index_list)
    neighbors_list = Map.to_list(neighbors_list)
    #IO.inspect neighbors_list
    GossipSimulator.Gossiper.set_neighbors(elem(lookup(index),1),neighbors_list)
  end
  
  defp grid_filter(count,index) do
    grid_dim = round(:math.sqrt(count))

    left_edge = Enum.filter(0..count-1, fn(x) -> if rem(x,grid_dim) == 0 do x end end)
    right_edge = Enum.filter(0..count-1, fn(x) -> if rem(x,grid_dim) == grid_dim-1 do x end end)
    top_edge = 0..grid_dim-1
    
    bottom_edge_start = 0
    cond do 
      grid_dim*grid_dim - count > 0 -> bottom_edge_start = grid_dim*(grid_dim-1)
      grid_dim*grid_dim - count == 0 -> bottom_edge_start = grid_dim*(grid_dim-1)
      right_corner = count-1
      true -> bottom_edge_start = grid_dim*grid_dim
    end
    bottom_edge = bottom_edge_start..count-1
        
    cond do
      Enum.member?(left_edge,index) -> res = [index-grid_dim,index+1,index+grid_dim]
      Enum.member?(right_edge,index) -> res = [index-grid_dim,index-1,index+grid_dim]
      Enum.member?(top_edge,index) ->  res = [index-1,index+grid_dim,index+1]
      Enum.member?(bottom_edge,index) -> res = [index-1,index-grid_dim,index+1]
      true -> res = [index-1,index-grid_dim,index+1,index+grid_dim]
    end
    res
  end

  ## Server Callbacks
  def init(:ok) do
    IO.puts "GossiperManager Starting..."
    {:ok, {%{},%{},{0,0},0}}
  end

  def handle_call({:lookup, index}, _from, state) do
    gossipers = elem(state,0)
    {:reply, Map.fetch(gossipers, index), state}
  end
  
  def handle_call({:get_gossipers_count}, _from, state) do
    {:reply, elem(state, 3), state}
  end

  def handle_call({:lookup_pairs, keys}, _from, state) do
    gossipers = elem(state,0)
    {:reply, Map.take(gossipers, keys), state}
  end
  
  def handle_cast({:add_gossipers}, state) do
    node_index = elem(state,3)
    gossipers = elem(state,0)
    if Map.has_key?(gossipers, node_index) do
      {:noreply, state}
    else
      {:ok, gossiper} = GossipSimulator.GossiperSupervisor.add_gossiper([node_index])
      gossipers = Map.put(gossipers, node_index, gossiper)
      state = put_elem(state,0,gossipers)
      state = put_elem(state,3,node_index+1)
      {:noreply, state}
    end
  end

  def handle_cast({:report_infection, msg}, state) do
    index = elem(msg,0)
    time = elem(msg,1)
    
    #IO.puts "First Gossip recieved at #{index} at relative time #{rel_time}"
    infection_report = elem(state,1)
    
    if Map.has_key?(infection_report, index) do
      {:noreply, state}
    else
      time_tuple = elem(state,2)
      rel_time = time - elem(time_tuple,0)
      infection_report = Map.put(infection_report, index, rel_time)
      state = put_elem(state,1,infection_report)
      if length(Map.values(infection_report)) == length(Map.values(elem(state,0))) do
        time_tuple = put_elem(time_tuple,1,time)
        state = put_elem(state,2,time_tuple)
        IO.puts "Gossip converged in #{rel_time} milliseconds"
      end
      {:noreply, state}
    end
  end
  
  def handle_cast({:set_start_time}, state) do
    time_tuple = elem(state,2)
    time_tuple = put_elem(time_tuple,0,:os.system_time(:millisecond))
    state = put_elem(state,2,time_tuple)
    {:noreply, state}
  end

  def handle_cast({:report_push_sum_convergence, node, time}, state) do
    start_time = elem(elem(state,2),0)
    rel_time = time - start_time
    IO.puts "hard convergence reached at #{node} in #{rel_time} milliseconds"
    {:noreply, state}
  end

end