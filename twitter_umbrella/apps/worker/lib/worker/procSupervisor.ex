defmodule Worker.ProcSupervisor do
  use Supervisor
  
  # A simple module attribute that stores the supervisor name
  @name Worker.ProcSupervisor
  
  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end
  
  def start_proc() do
    Supervisor.start_child(@name, [])
  end
  
  def init(:ok) do
    Supervisor.init([Worker.Proc], strategy: :simple_one_for_one)
  end
end
