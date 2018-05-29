defmodule PastryProtocol do
  @moduledoc """
  Documentation for PastryProtocol.
  """

  @doc """

  """
  def test(numNodes, numRequests) do
    PastryProtocol.MasterActor.start

    for i <- 1..numNodes do
      
      PastryProtocol.NodeActor.start String.to_atom("node" <> Integer.to_string(i))
    end
    
    for i <- 1..numNodes do
      PastryProtocol.NodeActor.pastryInit String.to_atom("node" <> Integer.to_string(i))
      :timer.sleep(10)
    end

    
    for i <- 1..numNodes do
      if numRequests > 0 do
        for j <- 1..numRequests, do: PastryProtocol.NodeActor.random_route(String.to_atom("node" <> Integer.to_string(i)), numNodes)
      end
    end
    
    IO.puts "Waiting 600 seconds for convergence..."
    res = PastryProtocol.MasterActor.get_result(numNodes, numRequests)

    t = 10*numNodes*numRequests + 800 |> round
    :timer.sleep(t)      
    
    IO.puts "average number of hops taken are #{res}" 
  end

  def main(argv) do
    numNodes = hd(argv)
    {numNodes,_} = Integer.parse(numNodes)

    argv = tl(argv)
    numRequests = hd(argv)
    {numRequests,_} = Integer.parse(numRequests)

    test(numNodes, numRequests)
  end
end
