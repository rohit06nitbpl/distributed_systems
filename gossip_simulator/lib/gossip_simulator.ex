defmodule GossipSimulator do
  use Application
  @moduledoc """
  Documentation for GossipSimulator.
  """

  @doc """
  
  """
  def start(_type, _args) do
    GossipSimulator.SimulatorSupervisor.start_link({1000,{:full,999},:gossip,{0,0}},[])
  end

  def main(argv) do
    numNodes = hd(argv)
    {numNodes,_} = Integer.parse(numNodes)
    argv = tl(argv)
    topology_name = hd(argv)
    argv = tl(argv)
    algorithm = hd(argv)
    msg = {0,0}
    case topology_name do
      "full"  -> topology = {:full,numNodes-1}
      "2D"    -> topology = {:grid2d,4}
      "line"  -> topology = {:line,2}
      "imp2D" -> topology = {:imp2d,5}
    end
    case algorithm do
      "gossip" -> algorithm = :gossip
      "push-sum" -> algorithm =:pushsum
    end

    args = {numNodes,topology,algorithm,msg}
    run(args)
  end

  defp run(args) do
    GossipSimulator.SimulatorSupervisor.start_link(args,[])
  end

end
