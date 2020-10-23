defmodule Pleroma.Repo.Migrations.RemoteipPlugRename do
  use Ecto.Migration

  import Ecto.Query

  def up do
    config =
      from(c in Pleroma.ConfigDB, where: c.group == ^:pleroma and c.key == ^Pleroma.Plugs.RemoteIp)
      |> Pleroma.Repo.one()

    if config do
      config
      |> Ecto.Changeset.change(key: Pleroma.Web.Plugs.RemoteIp)
      |> Pleroma.Repo.update()
    end
  end

  def down, do: :ok
end
