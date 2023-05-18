defmodule Ord do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    supervisor = Supervisor.start_link([
      {DynamicSupervisor, strategy: :one_for_one, name: Ord.Supervisor, max_seconds: 1, max_restarts: 999_999_999_999}
    ], strategy: :one_for_one)

    supervisor
  end
end