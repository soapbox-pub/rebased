defmodule Pleroma.Repo.Migrations.SetVisibleServiceActors do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.Repo

  def up do
    user_nicknames = ["relay", "internal.fetch"]

    from(
      u in "users",
      where: u.nickname in ^user_nicknames,
      update: [
        set: [invisible: true]
      ]
    )
    |> Repo.update_all([])
  end

  def down do
    :ok
  end
end
