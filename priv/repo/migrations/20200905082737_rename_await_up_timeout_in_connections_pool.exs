defmodule Pleroma.Repo.Migrations.RenameAwaitUpTimeoutInConnectionsPool do
  use Ecto.Migration

  def change do
    with %Pleroma.ConfigDB{} = config <-
           Pleroma.ConfigDB.get_by_params(%{group: :pleroma, key: :connections_pool}),
         {timeout, value} when is_integer(timeout) <- Keyword.pop(config.value, :await_up_timeout) do
      config
      |> Ecto.Changeset.change(value: Keyword.put(value, :connect_timeout, timeout))
      |> Pleroma.Repo.update()
    end
  end
end
