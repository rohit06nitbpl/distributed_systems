defmodule GossipSimulator.GossiperSupervisor do
  use Supervisor
  @moduledoc """
  """
  ## Client API

  @doc """
  """
  # A simple module attribute that stores the supervisor name
  @name GossipSimulator.GossiperSupervisor

  def start_link do
    ch_spec = Supervisor.child_spec(GossipSimulator.Gossiper, start: {GossipSimulator.Gossiper, :start_link, []})
    Supervisor.start_link([ch_spec], strategy: :simple_one_for_one, name: @name)
  end

  def add_gossiper(args) do
    Supervisor.start_child(@name, args)
  end
end