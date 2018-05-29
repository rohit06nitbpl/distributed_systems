defmodule Worker.Supervisor do
  use Supervisor
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end
  
  def init(:ok) do
    children = [
      Worker.ProcSupervisor,
      {Worker.Registry, name: Worker.Registry}
    ]
  
    Supervisor.init(children, strategy: :one_for_all) ##TODO Strategy
  end
end
