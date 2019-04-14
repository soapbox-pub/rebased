defmodule Pleroma.Repo.Migrations.MigrateOldBookmarks do
  use Ecto.Migration
  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.User
  alias Pleroma.Repo

  def up do
    Repo.all(User)
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
