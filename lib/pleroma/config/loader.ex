defmodule Pleroma.Config.Loader do
  @paths ["config/config.exs", "config/#{Mix.env()}.exs"]

  if Code.ensure_loaded?(Config.Reader) do
    @spec load(Path.t()) :: keyword()
    def load(path), do: Config.Reader.read!(path)

    defp do_merge(conf1, conf2), do: Config.Reader.merge(conf1, conf2)
  else
    # support for Elixir less than 1.9
    @spec load(Path.t()) :: keyword()
    def load(path) do
      {config, _paths} = Mix.Config.eval!(path)
      config
    end

    defp do_merge(conf1, conf2), do: Mix.Config.merge(conf1, conf2)
  end

  @spec load_and_merge() :: keyword()
  def load_and_merge do
    all_paths =
      if Pleroma.Config.get(:release),
        do: @paths ++ ["config/releases.exs"],
        else: @paths

    all_paths
    |> Enum.map(&load(&1))
    |> merge()
  end

  @spec merge([keyword()], keyword()) :: keyword()
  def merge(configs, acc \\ [])
  def merge([], acc), do: acc

  def merge([config | others], acc) do
    merge(others, do_merge(acc, config))
  end
end
