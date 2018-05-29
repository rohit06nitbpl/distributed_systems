defmodule GossipSimulator.SimulatorSupervisor do
  use Supervisor
  @moduledoc """
  
  """

  ## Client APIs
  @doc """
  
  """
  @name GossipSimulator.SimulatorSupervisor
  def start_link(args,_opts) do
    result = Supervisor.start_link(__MODULE__,[],name: @name)
    {numNodes,topology,algorithm,msg} = args
    
    IO.puts "#{numNodes}" <> " " <> "#{elem(topology,0)}" <>" "<>"#{elem(topology,1)}"<> " " <> "#{algorithm}"
    start_gossiperManager()
    start_gossiperSupervisor()
    GossipSimulator.GossiperManager.start_gossip(numNodes, topology, algorithm, msg)
       
    IO.puts "Waiting 600 seconds for convergence..."
    :timer.sleep(600000)
    result
  end

  def start_gossiperManager() do
    :supervisor.start_child(@name,worker(GossipSimulator.GossiperManager,[]))
  end

  def start_gossiperSupervisor() do
    :supervisor.start_child(@name,worker(GossipSimulator.GossiperSupervisor,[]))
  end 


  ## Server Callbacks
  def init(_) do
    Supervisor.init([], strategy: :one_for_one)
  end
end