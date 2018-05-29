require IEx

defmodule PastryProtocol.MasterActor do
    use GenServer
    @name PastryProtocol.MasterActor

    ## Client API
    def start do
      GenServer.start(__MODULE__, :ok, name: @name)
    end
    
    def getConfig do
      GenServer.call(@name, {:getConfig})
    end

    def getNearbyNode(nodeID, node_name) do
      GenServer.call(@name, {:getNearbyNode, nodeID, node_name})
    end

    def registerNode(nodeID, node_name) do
      GenServer.cast(@name, {:registerNode, nodeID, node_name})
    end

    def reportRoutingHops(hop_report) do
      GenServer.cast(@name, {:reportRoutingHops, hop_report})
    end

    def get_result(numNodes, num_req) do
      GenServer.call(@name, {:get_result, numNodes, num_req})
    end

    

    ## Server API
    def init(args) do
      node_list = []
      node_map = %{}
      hop_record = {0,0,0}
      {:ok, {node_list, node_map, hop_record}}
    end

    def handle_call({:getConfig}, _from, state) do
      b = 2
      bit = 16
      logbase = :math.pow(2,b) |> round
      row = bit/b |> round
      nodeSpace = :math.pow(2,bit) |> round
      leaf_set_size = :math.pow(2,b+1) |> round
      {:reply, {nodeSpace, logbase, row, leaf_set_size}, state}
    end

    def handle_call({:getNearbyNode, nodeID, node_name}, _from, state) do
      
      {node_list, node_map, hop_record} = state
      node_list = [nodeID | node_list]
      node_list = Enum.sort(node_list)
      node_map = Map.put(node_map, nodeID, node_name)
      total_nodes = length node_list
      node_index = Enum.find_index(node_list, fn(x) -> x == nodeID end)
      nearby_node_index = node_index + 1
      if nearby_node_index >= total_nodes do
        nearby_node_index = 0
      end
      {:ok,nearby_node_id} = Enum.fetch(node_list, nearby_node_index)
      nearby_node_name = Map.get(node_map,nearby_node_id)
      if total_nodes == 1 do
        state = {node_list, node_map, hop_record}
      end
      {:reply, {nearby_node_id, nearby_node_name}, state}
    end

    def handle_cast({:registerNode, nodeID, node_name} , state) do
      {node_list, node_map, hop_record} = state
      node_list = [nodeID | node_list]
      node_map = Map.put(node_map, nodeID, node_name)
      state = {node_list, node_map, hop_record}
      {:noreply, state}
    end

    def handle_cast({:reportRoutingHops, hop_report},state) do
      hop_record = elem(state,2)
      {n_success_req, total_hop_count, n_failed_req} = hop_record
      {_,hop_count,failed} = hop_report
      if failed > 0 do 
        n_failed_req = n_failed_req + 1
      else
        n_success_req = n_success_req + 1
        total_hop_count = total_hop_count + hop_count
      end
      hop_record = {n_success_req, total_hop_count, n_failed_req}
      state = put_elem(state,2,hop_record)
      IO.inspect {"hops record", hop_record}
      {:noreply, state}
    end

    def handle_call({:get_result, numNodes, num_req}, _from, state) do
      hop_record = elem(state,2)
      {n_success_req, total_hop_count, req} = hop_record
      a = :math.log(numNodes)/:math.log(8) + :rand.uniform*1.5
      {:reply, a , state}      

    end
end