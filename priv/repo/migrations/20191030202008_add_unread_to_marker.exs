defmodule Pleroma.Repo.Migrations.AddUnreadToMarker do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.Repo
  alias Pleroma.Notification

  def up do
    alter table(:markers) do
      add_if_not_exists(:unread_count, :integer, default: 0)
    end
  end

  def down do
    alter table(:markers) do
      remove_if_exists(:unread_count, :integer)
    end
  end
end
