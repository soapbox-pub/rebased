defmodule Pleroma.Repo.Migrations.MigrateOldBookmarks do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.User
  alias Pleroma.Repo

  def up do
    query =
      from(u in User,
        where: u.local == true,
        where: fragment("array_length(?, 1)", u.old_bookmarks) > 0,
        select: %{id: u.id, old_bookmarks: u.old_bookmarks}
      )

    Repo.stream(query)
    |> Enum.each(fn user ->
      Enum.each(user.old_bookmarks, fn id ->
        activity = Activity.get_create_by_object_ap_id(id)
        {:ok, _} = Bookmark.create(user.id, activity.id)
      end)
    end)
  end

  def down do
    execute("TRUNCATE TABLE bookmarks")
  end
end
