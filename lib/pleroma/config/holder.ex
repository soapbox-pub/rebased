defmodule Pleroma.Config.Loader do
  # TODO: add support for releases
  if Code.ensure_loaded?(Config.Reader) do
    @spec load() :: map()
    def load do
      config = load("config/config.exs")
      env_config = load("config/#{Mix.env()}.exs")

      Config.Reader.merge(config, env_config)
    end

    @spec load(Path.t()) :: keyword()
    def load(path), do: Config.Reader.read!(path)
  else
    # support for Elixir less than 1.9
    @spec load() :: map()
    def load do
      {config, _paths} = load("config/config.exs")
      {env_config, _paths} = load("config/#{Mix.env()}.exs")

      Mix.Config.merge(config, env_config)
    end

    @spec load(Path.t()) :: keyword()
    def load(path) do
      {config, _paths} = Mix.Config.eval!(path)
      config
    end
  end
end

defmodule Pleroma.Config.Holder do
  @config Pleroma.Config.Loader.load()

  @spec config() :: keyword()
  def config do
    @config
    |> Keyword.keys()
    |> Enum.map(&filter(&1, config(&1)))
    |> List.flatten()
  end

  @spec config(atom()) :: any()
  def config(group), do: @config[group]

  @spec config(atom(), atom()) :: any()
  def config(group, key), do: @config[group][key]

  defp filter(group, settings) when group not in [:swarm] do
    filtered =
      Enum.reject(settings, fn {k, _v} ->
        k in [Pleroma.Repo, Pleroma.Web.Endpoint, :env, :configurable_from_database] or
          (group == :phoenix and k == :serve_endpoints)
      end)

    {group, filtered}
  end

  defp filter(_, _), do: []
end
