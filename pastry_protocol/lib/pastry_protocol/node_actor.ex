require IEx

defmodule PastryProtocol.NodeActor do
    use GenServer

    ## Client API
    def start(node_name) do
      GenServer.start(__MODULE__, :ok, name: node_name)
    end
    
    def get_state(node_name) do
      GenServer.call(node_name, {:get_state})
    end

    def pastryInit(node_name) do
      GenServer.cast(node_name,{:pastryInit, node_name})
    end

    def route(node_name, msg, key) do
      
      GenServer.cast(node_name,{:route, node_name, msg, key})
    end

    def random_route(node_name, numNodes) do
      
      msg = {:forward,0}
      key_name = String.to_atom("node" <> Integer.to_string(Enum.random(1..numNodes)))
      key_id = get_node_id(key_name, 4, 8)
      key = {key_id, key_name}

      GenServer.cast(node_name,{:route, node_name, msg, key})

    end

    def final_join(node_name,msg,key) do
      GenServer.cast(node_name,{:final_join, node_name, msg, key})
    end

    def final_forward(node_name,msg,key) do
      GenServer.cast(node_name,{:final_forward, msg, key})
    end

    def shl(a,b) do
      Enum.find_index(0..String.length(a)-1, fn i -> String.at(a,i) != String.at(b,i) end)
    end

    def string_to_int(string) do
      elem(Integer.parse(string),0)
    end

    def in_left_range(nodeID, key_id, leaf_id, nodeSpace) do

      is_in_range = false
      if leaf_id > nodeID do
        if key_id < nodeID do
          key_id = key_id + nodeSpace
          is_in_range = key_id > leaf_id
        else 
          is_in_range = key_id >= leaf_id
        end
      else
        if key_id >= leaf_id and key_id < nodeID do
          is_in_range = true
        end
      end
      is_in_range
    end

    def in_right_range(nodeID, key_id, leaf_id, nodeSpace) do
      is_in_range = false
      if leaf_id < nodeID do
        leaf_id = leaf_id + nodeSpace
        if key_id < nodeID do
          key_id = key_id + nodeSpace
          is_in_range = key_id <= leaf_id
        else
          is_in_range = key_id < leaf_id
        end
      else
        if key_id <= leaf_id and key_id > nodeID do
          is_in_range = true
        end
      end
      is_in_range
    end

    def in_leaf_set(left_leaf_set,right_leaf_set,key_id,nodeID, nodeSpace) do
      
      key_id = string_to_int(key_id)
      nodeID = string_to_int(nodeID)
      
      is_in_leaf_set = false
      if key_id == nodeID do
        is_in_leaf_set = true
      else
        #left = Enum.take_while(left_leaf_set, fn(x) -> in_left_range(nodeID, key_id, string_to_int(x), nodeSpace) end)
        left = for x <- left_leaf_set, do: in_left_range(nodeID, key_id, string_to_int(x), nodeSpace)
        found_in_left = Enum.find(left, fn(x) -> x == true end)
        if found_in_left == nil do
          #right = Enum.take_while(right_leaf_set, fn(x) -> in_right_range(nodeID, key_id, string_to_int(x), nodeSpace) end)
          right = for x <- right_leaf_set, do: in_right_range(nodeID, key_id, string_to_int(x), nodeSpace)
          found_in_right = Enum.find(right, fn(x) -> x == true end)
          if found_in_right != nil do
            is_in_leaf_set = true
          end
        else
          is_in_leaf_set = true
        end
      end
      is_in_leaf_set
    end

    def do_leaf(leaf_list, nodeID, leaf_set_size) do
      leaf_list = Enum.sort(leaf_list)
      {less_leaf_list, gtr_leaf_list} = Enum.split_while(leaf_list, fn(x) -> x < nodeID end)
      if length(less_leaf_list) > length(gtr_leaf_list) do
        diff = length(less_leaf_list) - length(gtr_leaf_list)
        num_ele_to_move = diff/2 |> round
        {to_move, less_leaf_list} = Enum.split(less_leaf_list, num_ele_to_move)
        gtr_leaf_list = gtr_leaf_list ++ to_move
      else 
        diff =  length(gtr_leaf_list) - length(less_leaf_list)
        num_ele_to_move = diff/2 |> round
        {gtr_leaf_list, to_move} = Enum.split(gtr_leaf_list, length(gtr_leaf_list)-num_ele_to_move)
        less_leaf_list = less_leaf_list ++ to_move
      end
      less_leaf_list = Enum.sort(less_leaf_list)
      gtr_leaf_list = Enum.sort(gtr_leaf_list)

      half_leaf_set_size = leaf_set_size/2 |> round
      if length(less_leaf_list) - half_leaf_set_size > 0 do
        {to_remove,less_leaf_list} = Enum.split(less_leaf_list, length(less_leaf_list) - half_leaf_set_size)
      end

      if length(gtr_leaf_list) - half_leaf_set_size > 0 do
        {gtr_leaf_list,to_remove} = Enum.split(gtr_leaf_list, half_leaf_set_size)
      end
      {less_leaf_list, gtr_leaf_list}
    end

    def get_node_id(node_name, logbase, row) do
      nodeID = :crypto.hash(:sha256, Atom.to_string(node_name)) |> Base.encode16 |> Integer.parse(16) |> elem(0) |> Integer.to_string(logbase) |> String.slice(0..row-1)
    end

    def append_to_file(file, msg) do
      msg = inspect msg
      IO.binwrite file, msg
      IO.binwrite file, "\n"
    end

    def print_reverse_list(node_name, list_msg) do
      if false and list_msg != [] do
        node_name = Atom.to_string(node_name)
        {:ok, file} = File.open node_name, [:append]
        IO.binwrite file, "\n"
        list_msg = Enum.reverse(list_msg)
        Enum.each(list_msg, fn(x) -> append_to_file(file,x) end)
        IO.binwrite file, "\n"
      end
    end

    ## Server API
    def init(args) do
      nodeID = -1
      node_map = %{}
      left_leaf_set = []
      right_leaf_set = []
      routing_map = %{}
      ## neighbor set not neccesary for this implementation
      config = {-1,-1,-1,-1}
      tuple_list_for_join = []
      {:ok, {nodeID, node_map, left_leaf_set, right_leaf_set, routing_map, config, tuple_list_for_join}}
    end

    def handle_cast({:pastryInit, node_name}, state) do
      {nodeSpace,logbase,row,leaf_set_size} = PastryProtocol.MasterActor.getConfig
      nodeID = get_node_id(node_name, logbase, row)
      routing_map = for i <- 0..logbase*row-1 , into: elem(state,4), do: {i,"-1"}
      routing_map = for i <- 0..row-1 , into: routing_map, do: {i*logbase + elem(Integer.parse(String.at(nodeID,i)),0), nodeID}

      state = put_elem(state, 0, nodeID)
      state = put_elem(state, 1, Map.put(elem(state,1),nodeID,node_name))
      state = put_elem(state, 4, routing_map)
      state = put_elem(state, 5, {nodeSpace,logbase,row,leaf_set_size})
      {nearby_node_id, nearby_node_name} = PastryProtocol.MasterActor.getNearbyNode(nodeID, node_name)
      if nearby_node_name != node_name do #atleast two node in ring 
        route(nearby_node_name, {:join,0}, {nodeID, node_name})
      end
      {:noreply, state}
    end

    

    def handle_cast({:route, node_name, msg, key},state) do
      
      {nodeID, node_map, left_leaf_set, right_leaf_set, routing_map, {nodeSpace,logbase,row,leaf_set_size}, tuple_list_for_join} = state
      {key_id, key_name} = key
      {msg_head, msg_body} = msg
      
      to_print_list = []
      to_print_list = [{node_name, "route, state", state}|to_print_list]
      to_print_list = [{node_name, "route, msg", msg}|to_print_list]
      to_print_list = [{node_name, "route, key", key}|to_print_list]

      leaf_list = left_leaf_set ++ [nodeID] ++ right_leaf_set
      if in_leaf_set(left_leaf_set,right_leaf_set,key_id,nodeID, nodeSpace) do
        route_to_node = Enum.min_by(leaf_list, fn(x) -> abs(string_to_int(key_id)-string_to_int(x)) end, fn -> "-1" end)
        to_print_list = [{node_name, "route, first_condition", route_to_node}|to_print_list]
        case msg_head do
          :join ->
            if route_to_node != nodeID do
              msg_body = msg_body + 1
              msg = {msg_head, msg_body}
              l = shl(key_id, nodeID)
              key_routing_map = for i <- 0..logbase-1 , into: %{}, do: {l*logbase + i, elem(Map.fetch(routing_map, l*logbase + i),1)}
              key_node_map = Map.take(node_map, Map.values(key_routing_map))

              to_print_list = [{node_name, "route, first_condition, route_to_node != nodeID, shl", l}|to_print_list]
              to_print_list = [{node_name, "route, first_condition, route_to_node != nodeID, key_routing_map", key_routing_map}|to_print_list]
              to_print_list = [{node_name, "route, first_condition, route_to_node != nodeID, key_node_map", key_node_map}|to_print_list]

              GenServer.cast(key_name,{:join_reply, {nodeID,node_name}, key_routing_map, key_node_map})
            end
            to_print_list = [{node_name, "route, first_condition, route_to_node == nodeID"}|to_print_list]
            elem(Map.fetch(node_map,route_to_node),1) |> final_join(msg, key)
          :forward ->
            if route_to_node != nodeID do
              msg_body = msg_body + 1
              msg = {msg_head, msg_body}
            end
            route_node_name = Map.fetch(node_map,route_to_node) 
            if route_node_name == :error do
              IO.inspect {"routing to node",route_to_node, "at node", node_name, "for key",key_name, "state",state}
            else 
              final_forward(elem(route_node_name,1), msg, key)
            end
        end
      else
        row_index = shl(key_id,nodeID)
        col_index = string_to_int(String.at(key_id,row_index))
        actual_index = logbase*row_index + col_index
        route_to_node = elem(Map.fetch(routing_map, actual_index),1)
        to_print_list = [{node_name, "route, second_condition_prep", row_index, col_index, actual_index}|to_print_list]
        if  route_to_node != "-1" do
          msg_body = msg_body + 1
          msg = {msg_head, msg_body}
          case msg_head do
            :join ->
              l = row_index
              key_routing_map = for i <- 0..logbase-1 , into: %{}, do: {l*logbase + i, elem(Map.fetch(routing_map, l*logbase + i),1)}
              key_node_map = Map.take(node_map, Map.values(key_routing_map))
              to_print_list = [{node_name, "route, second_condition_real, key_routing_map", key_routing_map }|to_print_list]
              to_print_list = [{node_name, "route, second_condition_real, key_node_map", key_node_map }|to_print_list]
              GenServer.cast(key_name,{:join_reply, {nodeID,node_name}, key_routing_map, key_node_map})
              elem(Map.fetch(node_map,route_to_node),1) |> route(msg, key)
            :forward ->
              elem(Map.fetch(node_map,route_to_node),1) |> route(msg, key)
          end
        else
          routing_list = for i <- row_index*logbase..row*logbase-1 , into: [], do: elem(Map.fetch(routing_map, i),1) 
          filtered_leaf_list = Enum.filter(leaf_list, fn(x) -> shl(key_id,x) >= row_index end)
          total_list = routing_list ++ filtered_leaf_list
          filtered_total_list = Enum.filter(total_list, fn(x) -> x != "-1" and x != nodeID end)
          route_to_node = Enum.min_by(filtered_total_list, fn(x) -> abs(string_to_int(key_id)-string_to_int(x)) - abs(string_to_int(key_id)-string_to_int(nodeID)) end, fn -> "-1" end)
          to_print_list = [{node_name, "route, third_condition_prep, routing_list", routing_list}|to_print_list]
          to_print_list = [{node_name, "route, third_condition_prep, filtered_leaf_list", filtered_leaf_list}|to_print_list]
          to_print_list = [{node_name, "route, third_condition_prep, filtered_total_list", filtered_total_list}|to_print_list]
          to_print_list = [{node_name, "route, third_condition_prep, route_to_node", route_to_node}|to_print_list]
          if route_to_node != "-1" do
            msg_body = msg_body + 1
            msg = {msg_head, msg_body}
            case msg_head do
              :join ->
                l = row_index
                key_routing_map = for i <- 0..logbase-1 , into: %{}, do: {l*logbase + i, elem(Map.fetch(routing_map, l*logbase + i),1)}
                key_node_map = Map.take(node_map, Map.values(key_routing_map))
                to_print_list = [{node_name, "route, third_condition_real, key_routing_map", key_routing_map}|to_print_list]
                to_print_list = [{node_name, "route, third_condition_real, key_node_map", key_node_map}|to_print_list]
                GenServer.cast(key_name,{:join_reply, {nodeID,node_name}, key_routing_map, key_node_map})
                elem(Map.fetch(node_map,route_to_node),1) |> route(msg, key)
              :forward ->
                elem(Map.fetch(node_map,route_to_node),1) |> route(msg, key)
            end
          else
            case msg_head do
              :join ->
                IO.puts "No element in third routing condition as well at (#{nodeID}, #{node_name}) for (#{key_id} , #{key_name}) , joining here by final_join.."
                elem(Map.fetch(node_map,nodeID),1) |> final_join(msg, key)
              :forward ->
                IO.puts "No element in third routing condition as well at (#{nodeID} , #{node_name}) , routing failed for (#{key_id} , #{key_name}) !!"
                PastryProtocol.MasterActor.reportRoutingHops {0,0,1}
            end
          end
        end
      end
      to_print_list = [{node_name, "route, final state", state}|to_print_list]
      print_reverse_list(node_name, to_print_list)
      {:noreply, state}
    end

    def handle_cast({:final_join, node_name, msg, key}, state) do
      
      {nodeID, node_map, left_leaf_set, right_leaf_set, routing_map, {nodeSpace,logbase,row,leaf_set_size}, tuple_list_for_join} = state
      {key_id, key_name} = key

      to_print_list = []
      to_print_list = [{node_name, "final_join, state", state}|to_print_list]
      to_print_list = [{node_name, "final_join, msg", msg}|to_print_list]
      to_print_list = [{node_name, "final_join, key", key}|to_print_list]

      l = shl(key_id, nodeID)
      key_routing_map = for i <- 0..logbase-1 , into: %{}, do: {l*logbase + i, elem(Map.fetch(routing_map, l*logbase + i),1)}
      key_node_map = Map.take(node_map, Map.values(key_routing_map))
      key_left_leaf_map = Map.take(node_map, left_leaf_set)
      key_right_leaf_map = Map.take(node_map, right_leaf_set)
      to_print_list = [{node_name, "final_join, l", l}|to_print_list]
      to_print_list = [{node_name, "final_join, key_routing_map", key_routing_map}|to_print_list]
      to_print_list = [{node_name, "final_join, key_node_map", key_node_map}|to_print_list]
      to_print_list = [{node_name, "final_join, key_left_leaf_map", key_left_leaf_map}|to_print_list]
      to_print_list = [{node_name, "final_join, key_right_leaf_map", key_right_leaf_map}|to_print_list]
      GenServer.cast(key_name,{:final_join_reply, {nodeID,node_name}, key_routing_map, left_leaf_set, key_left_leaf_map, right_leaf_set, key_right_leaf_map, key_node_map})

      to_print_list = [{node_name, "route, final state", state}|to_print_list]
      print_reverse_list(node_name, to_print_list)

      {:noreply, state}
    end

    def handle_cast({:final_forward, msg, key},state) do
      {msg_head, msg_body} = msg
      msg_body = msg_body + 1
      msg = {msg_head, msg_body}
      PastryProtocol.MasterActor.reportRoutingHops {1,msg_body,0}
      {:noreply, state}
    end

    def handle_cast({:join_reply, {nodeID_in,node_name_in}, key_routing_map, key_node_map}, state) do
      {nodeID, node_map, left_leaf_set, right_leaf_set, routing_map, {nodeSpace,logbase,row,leaf_set_size}, tuple_list_for_join} = state
      
      to_print_list = []
      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":join_reply, state", state}|to_print_list]
      
      routing_map = Map.merge(routing_map,key_routing_map)
      node_map = Map.merge(node_map,key_node_map)
      tuple_list_for_join = [{nodeID_in,node_name_in}|tuple_list_for_join]

      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":join_reply, routing_map", routing_map}|to_print_list]
      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":join_reply, node_map", node_map}|to_print_list]
      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":join_reply, tuple_list_for_join", tuple_list_for_join}|to_print_list]

      state = put_elem(state, 4, routing_map)
      state = put_elem(state, 1, node_map)
      state = put_elem(state, 6, tuple_list_for_join)

      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), "route, final state", state}|to_print_list]
      print_reverse_list(elem(Map.fetch(node_map,nodeID),1), to_print_list)

      {:noreply, state}
    end

    def handle_cast({:final_join_reply, {nodeID_in,node_name_in}, key_routing_map, left_leaf_set_in, key_left_leaf_map, right_leaf_set_in, key_right_leaf_map, key_node_map}, state)  do
      {nodeID, node_map, left_leaf_set, right_leaf_set, routing_map, {nodeSpace,logbase,row,leaf_set_size}, tuple_list_for_join} = state
      
      to_print_list = []
      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":final_join_reply, state", state}|to_print_list]
      
      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":final_join_reply, input, key_routing_map", key_routing_map}|to_print_list]
      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":final_join_reply, input, left_leaf_set_in", left_leaf_set_in}|to_print_list]
      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":final_join_reply, input, key_left_leaf_map", key_left_leaf_map}|to_print_list]
      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":final_join_reply, input, right_leaf_set_in", right_leaf_set_in}|to_print_list]
      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":final_join_reply, input, key_right_leaf_map", key_right_leaf_map}|to_print_list]
      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":final_join_reply, input, key_node_map", key_node_map}|to_print_list]

      

      routing_map = Map.merge(routing_map,key_routing_map)
      node_map = Map.merge(node_map,key_node_map)
      key_left_leaf_map = Map.merge(key_left_leaf_map,%{nodeID_in => node_name_in})
      key_right_leaf_map = Map.merge(key_right_leaf_map,%{nodeID_in => node_name_in})

      

      tuple_list_for_join = [{nodeID_in,node_name_in}|tuple_list_for_join]
      
      leaf_list = left_leaf_set_in ++ [nodeID_in] ++ right_leaf_set_in
      {right_leaf_set, left_leaf_set} = do_leaf(leaf_list, nodeID, leaf_set_size)

      
      
      key_left_leaf_map = Map.take(key_left_leaf_map, left_leaf_set)
      key_right_leaf_map = Map.take(key_right_leaf_map, right_leaf_set)

      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":final_join_reply, right_leaf_set", right_leaf_set}|to_print_list]
      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":final_join_reply, key_right_leaf_map", key_right_leaf_map}|to_print_list]
      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":final_join_reply, left_leaf_set", left_leaf_set}|to_print_list]
      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":final_join_reply, key_left_leaf_map", key_left_leaf_map}|to_print_list]

      node_map = Map.merge(node_map,key_left_leaf_map)
      node_map = Map.merge(node_map,key_right_leaf_map)

      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), ":final_join_reply, node_map", node_map}|to_print_list]

      Enum.each(tuple_list_for_join, fn(x) -> GenServer.cast(elem(x,1),{:node_joined, {nodeID, elem(Map.fetch(node_map,nodeID),1)} }) end)
      state = {nodeID, node_map, left_leaf_set, right_leaf_set, routing_map, {nodeSpace,logbase,row,leaf_set_size}, tuple_list_for_join} 
      
      PastryProtocol.MasterActor.registerNode(nodeID, elem(Map.fetch(node_map,nodeID),1))

      to_print_list = [{elem(Map.fetch(node_map,nodeID),1), "route, final state", state}|to_print_list]
      print_reverse_list(elem(Map.fetch(node_map,nodeID),1), to_print_list)
      
      {:noreply, state}
    end

    def handle_cast({:node_joined, joined_node}, state) do
      {nodeID, node_map, left_leaf_set, right_leaf_set, routing_map, {nodeSpace,logbase,row,leaf_set_size}, tuple_list_for_join} = state
      {joined_node_id, joined_node_name} = joined_node
      
      node_map = Map.put(node_map, joined_node_id, joined_node_name)

      leaf_list = left_leaf_set ++ [joined_node_id] ++ right_leaf_set
      {right_leaf_set, left_leaf_set} = do_leaf(leaf_list, nodeID, leaf_set_size)

      row_index = shl(joined_node_id, nodeID)
      col_index = string_to_int(String.at(joined_node_id,row_index))
      actual_index = row_index*logbase + col_index

      {:ok, ele_id_in_table} = Map.fetch(routing_map, actual_index)

      if joined_node_id < ele_id_in_table do
        routing_map = Map.delete(routing_map,actual_index)
        routing_map = Map.put(routing_map, actual_index, joined_node_id)
      end

      all_ids = [nodeID] ++ left_leaf_set ++ right_leaf_set ++ Map.values(routing_map)
      node_map = Map.take(node_map, all_ids)

      state = {nodeID, node_map, left_leaf_set, right_leaf_set, routing_map, {nodeSpace,logbase,row,leaf_set_size}, tuple_list_for_join}
      {:noreply, state}
    end

    def handle_call({:get_state}, _from, state) do
      {:reply, state, state}
    end
    
end