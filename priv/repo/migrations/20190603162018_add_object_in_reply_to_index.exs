defmodule Pleroma.Repo.Migrations.AddObjectInReplyToIndex do
  use Ecto.Migration

  def change do
    create(index(:objects, ["(data->>'inReplyTo')"], name: :objects_in_reply_to_index))
  end
end
