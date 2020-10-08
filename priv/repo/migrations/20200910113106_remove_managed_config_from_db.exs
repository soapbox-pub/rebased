defmodule Pleroma.Repo.Migrations.RemoveManagedConfigFromDb do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.ConfigDB
  alias Pleroma.Repo

  def up do
    config_entry =
      from(c in ConfigDB,
        select: [:id, :value],
        where: c.group == ^:pleroma and c.key == ^:instance
      )
      |> Repo.one()

    if config_entry do
      {_, value} = Keyword.pop(config_entry.value, :managed_config)

      config_entry
      |> Ecto.Changeset.change(value: value)
      |> Repo.update()
    end
  end

  def down do
    :ok
  end
end
