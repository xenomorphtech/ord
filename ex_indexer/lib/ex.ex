defmodule Ord do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    supervisor = Supervisor.start_link([
      {DynamicSupervisor, strategy: :one_for_one, name: Ord.Supervisor, max_seconds: 1, max_restarts: 999_999_999_999}
    ], strategy: :one_for_one)

    path = Path.join([Application.fetch_env!(:ord, :work_folder), "mnesia_kv/"])
    MnesiaKV.load(%{
        MainChain => %{key_type: :elixir_term, index: [:block]},
        #Block => %{index: [:height]},
        #TX => %{index: [:block]},
      },
      %{path: path}
    )

    {:ok, _} = DynamicSupervisor.start_child(Ord.Supervisor, %{
      id: Ord.GenIndexer, start: {Ord.GenIndexer, :start_link, []}
    })

    supervisor
  end
end