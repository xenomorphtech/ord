defmodule Ord.MixProject do
  use Mix.Project

  @app :ord

  def project do
    [
      app: @app,
      version: "0.0.10",
      elixir: "~> 1.14.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      build_embedded: Mix.env == :prod,
      releases: [{@app, release()}],
      preferred_cli_env: [release: :prod]
    ]
  end

  def application do
    apps = [
      extra_applications: [:iex, :logger, :crypto, :ssl, :inets]
    ]
    if Mix.env() == :prod do
      [{:mod, {Ord.Bakeware, []}} | apps]
    else
      [{:mod, {Ord, []}} | apps]
    end
  end

  defp deps do
    [
      {:bakeware, git: "https://github.com/bake-bake-bake/bakeware", branch: "main", runtime: false},

      {:photon, git: "https://github.com/vans163/photon.git"},
      {:mnesia_kv, git: "https://github.com/xenomorphtech/mnesia_kv.git"},
    ]
  end

  defp release do
    [
      overwrite: true,
      steps: [:assemble, &Bakeware.assemble/1],
      strip_beams: Mix.env() == :prod,
      bakeware: [
        compression_level: 1,
        #compression_level: 19,
        start_command: "start_iex"
      ],
    ]
  end
end
