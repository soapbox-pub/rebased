defmodule Pleroma.Repo.Migrations.MigrateOldBookmarks do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.Repo

  def up do
    query =
      from(u in "users",
        where: u.local == true,
        where: fragment("array_length(?, 1)", u.bookmarks) > 0,
        select: %{id: u.id, bookmarks: u.bookmarks}
      )

    Repo.stream(query)
    |> Enum.each(fn %{id: user_id, bookmarks: bookmarks} ->
      Enum.each(bookmarks, fn ap_id ->
        activity =
          ap_id
          |> Activity.create_by_object_ap_id()
          |> Repo.one()

        unless is_nil(activity), do: {:ok, _} = Bookmark.create(user_id, activity.id)
      end)
    end)

    alter table(:users) do
      remove(:bookmarks)
    end
  end

  def down do
    alter table(:users) do
      add(:bookmarks, {:array, :string}, null: false, default: [])
    end
  end
end
