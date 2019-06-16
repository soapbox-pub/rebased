defmodule Pleroma.Config.TransferTask do
  use Task
  alias Pleroma.Web.AdminAPI.Config

  def start_link do
    load_and_update_env()
    if Pleroma.Config.get(:env) == :test, do: Ecto.Adapters.SQL.Sandbox.checkin(Pleroma.Repo)
    :ignore
  end

  def load_and_update_env do
    if Pleroma.Config.get([:instance, :dynamic_configuration]) and
         Ecto.Adapters.SQL.table_exists?(Pleroma.Repo, "config") do
      Pleroma.Repo.all(Config)
      |> Enum.each(&update_env(&1))
    end
  end

  defp update_env(setting) do
    try do
      key =
        if String.starts_with?(setting.key, "Pleroma.") do
          "Elixir." <> setting.key
        else
          setting.key
        end

      Application.put_env(
        :pleroma,
        String.to_existing_atom(key),
        Config.from_binary(setting.value)
      )
    rescue
      e ->
        require Logger

        Logger.warn(
          "updating env causes error, key: #{inspect(setting.key)}, error: #{inspect(e)}"
        )
    end
  end
end
