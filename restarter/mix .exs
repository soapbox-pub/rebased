defmodule Restarter.MixProject do
  use Mix.Project

  def project do
    [
      app: :restarter,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Restarter, []}
    ]
  end

  defp deps, do: []
end
