defmodule Pleroma.Repo.Migrations.AutolinkerToLinkify do
  use Ecto.Migration
  alias Pleroma.ConfigDB

  @autolinker_path %{group: :auto_linker, key: :opts}
  @linkify_path %{group: :pleroma, key: Pleroma.Formatter}

  @compat_opts [:class, :rel, :new_window, :truncate, :strip_prefix, :extra]

  def change do
    with {:ok, {old, new}} <- maybe_get_params() do
      move_config(old, new)
    end
  end

  defp move_config(%{} = old, %{} = new) do
    {:ok, _} = ConfigDB.update_or_create(new)
    {:ok, _} = ConfigDB.delete(old)
    :ok
  end

  defp maybe_get_params() do
    with %ConfigDB{value: opts} <- ConfigDB.get_by_params(@autolinker_path),
         opts <- transform_opts(opts),
         %{} = linkify_params <- Map.put(@linkify_path, :value, opts) do
      {:ok, {@autolinker_path, linkify_params}}
    end
  end

  def transform_opts(opts) when is_list(opts) do
    opts
    |> Enum.into(%{})
    |> Map.take(@compat_opts)
    |> Map.to_list()
  end
end
