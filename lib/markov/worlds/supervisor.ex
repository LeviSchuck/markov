defmodule Markov.Worlds.Supervisor do
  use Supervisor
  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      worker(Markov.World, [])
    ]

    # supervise/2 is imported from Supervisor.Spec
    supervise(children, strategy: :simple_one_for_one)
  end

  def add_world(name) do
    Supervisor.start_child(__MODULE__, [name])
  end
  
end
