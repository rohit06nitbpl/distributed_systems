defmodule GossipSimulator.Gossiper do
  use GenServer
  @moduledoc """
  """
  ## Client API
  @doc """
  """
  def start_link(args, _opts \\ []) do
    GenServer.start_link(__MODULE__, args, _opts)
  end

  def set_neighbors(server, neighbors_list) do
    GenServer.cast(server, {:set_neighbors, neighbors_list})
  end

  def gossip(server,algorithm, msg, max_msg_in, max_msg_out) do
    if algorithm == :gossip do
        handle_gossip(server,algorithm, msg, max_msg_in, max_msg_out)
    end

    if algorithm == :pushsum do
      handle_pushsum(server,algorithm, msg, max_msg_in, max_msg_out)
    end
    
  end

  defp push_gossip(server,algorithm, msg, max_msg_in, max_msg_out,counter) do
    if counter > 0 do
      GenServer.cast(server, {:push_gossip, algorithm, msg, max_msg_in, max_msg_out})
      push_gossip(server,algorithm, msg, max_msg_in, max_msg_out,counter-1)
    end
  end

  defp get_n_msg_recieved(server) do
    GenServer.call(server,{:get_n_msg_recieved})
  end
  
  defp handle_gossip(server,algorithm, msg, max_msg_in, max_msg_out) do
    GenServer.cast(server,{:handle_gossip, algorithm, msg, max_msg_in, max_msg_out})
  end

  defp handle_pushsum(server,algorithm, msg, max_msg_in, max_msg_out) do
    GenServer.cast(server,{:handle_pushsum, algorithm, msg, max_msg_in, max_msg_out})
  end
  
  ## Server Callbacks
  def init(index) do
    {:ok, {index,[],{},0}}
  end

  def handle_call({:get_n_msg_recieved},_from, state) do
    {:reply,elem(state,3),state}
  end

  def handle_cast({:handle_gossip, algorithm, msg, max_msg_in, max_msg_out},state) do
    state = put_elem(state, 3, elem(state,3)+1)
    if elem(state,3) == 1 do
      GossipSimulator.GossiperManager.report_infection({elem(state,0),:os.system_time(:millisecond)})
      push_gossip(self(),algorithm, msg, max_msg_in, max_msg_out,max_msg_out)
    end
    if elem(state,3) > max_msg_in do
      IO.puts "hard convergence reached at #{elem(state,0)} node"      
    end
    {:noreply,state}
  end

  def handle_cast({:set_neighbors, neighbors_list}, state) do
    state = put_elem(state,1,neighbors_list)
    {:noreply,state}
  end

  def handle_cast({:push_gossip, algorithm, msg, max_msg_in, max_msg_out}, state) do
    #IO.inspect state
    try do
      selected_neighbor = Enum.random(elem(state,1))
      state = put_elem(state,1,elem(state,1)--[selected_neighbor])
      #IO.puts "Sending Gossip from #{elem(state,0)} to #{elem(selected_neighbor,0)}"
      gossip(elem(selected_neighbor,1), algorithm, msg, max_msg_in, max_msg_out)
      {:noreply, state}
    rescue
      _ -> {:noreply, state}
    end
  end

  def handle_cast({:handle_pushsum, algorithm, msg, max_msg_in, max_msg_out}, state) do
    try do
      selected_neighbor = Enum.random(elem(state,1))
      stop = false
      case elem(state,2) do
        {} -> 
        msg = {(elem(state,0)+elem(msg,0))/2,(1+elem(msg,1))/2}
        state = put_elem(state,2,Tuple.insert_at(msg,2,0))
        #IO.puts "#{elem(state,0)} new state and msg: #{elem(msg,0)} , #{elem(msg,1)}"
        
        {s,w,_} -> 
        prev_ratio = s/w
        #IO.puts "#{elem(state,0)}, #{s} , #{w} , msg recieved : #{elem(msg,0)} , #{elem(msg,1)}"
        msg = {(elem(elem(state,2),0)+elem(msg,0))/2,(elem(elem(state,2),1)+elem(msg,1))/2}
        same_delta_count = elem(elem(state,2),2)
        #IO.inspect elem(msg,0)/elem(msg,1)
        new_ratio = elem(msg,0)/elem(msg,1)
        delta = abs(new_ratio-prev_ratio)
        #IO.inspect delta
        if  delta < 10.0e-10 do
          same_delta_count = same_delta_count + 1
        else 
          same_delta_count = 0
        end
        state = put_elem(state,2,Tuple.insert_at(msg,2,same_delta_count))
        #IO.inspect state
        if same_delta_count >= 3 do
          #IO.inspect state
          stop = true
        end
      end

      if stop != true do
        gossip(elem(selected_neighbor,1), algorithm, msg, max_msg_in, max_msg_out)
        {:noreply, state}
      else 
        GossipSimulator.GossiperManager.report_push_sum_convergence(elem(state,0),:os.system_time(:millisecond))
        {:noreply, state}
      end

    rescue
      _ -> {:noreply, state}
    end
  end
end