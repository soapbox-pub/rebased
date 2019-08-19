# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.TransferTask do
  use Task
  alias Pleroma.Web.AdminAPI.Config

  def start_link(_) do
    load_and_update_env()
    if Pleroma.Config.get(:env) == :test, do: Ecto.Adapters.SQL.Sandbox.checkin(Pleroma.Repo)
    :ignore
  end

  def load_and_update_env do
    if Pleroma.Config.get([:instance, :dynamic_configuration]) and
         Ecto.Adapters.SQL.table_exists?(Pleroma.Repo, "config") do
      for_restart =
        Pleroma.Repo.all(Config)
        |> Enum.map(&update_env(&1))

      # We need to restart applications for loaded settings take effect
      for_restart
      |> Enum.reject(&(&1 in [:pleroma, :ok]))
      |> Enum.each(fn app ->
        Application.stop(app)
        :ok = Application.start(app)
      end)
    end
  end

  defp update_env(setting) do
    try do
      key =
        if String.starts_with?(setting.key, "Pleroma.") do
          "Elixir." <> setting.key
        else
          String.trim_leading(setting.key, ":")
        end

      group = String.to_existing_atom(setting.group)

      Application.put_env(
        group,
        String.to_existing_atom(key),
        Config.from_binary(setting.value)
      )

      group
    rescue
      e ->
        require Logger

        Logger.warn(
          "updating env causes error, key: #{inspect(setting.key)}, error: #{inspect(e)}"
        )
    end
  end
end
