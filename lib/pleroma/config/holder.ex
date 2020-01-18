defmodule Pleroma.Config.Holder do
  @config Pleroma.Config.Loader.load_and_merge()

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
