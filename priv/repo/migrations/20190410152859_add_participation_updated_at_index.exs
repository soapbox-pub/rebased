defmodule Pleroma.Repo.Migrations.AddParticipationUpdatedAtIndex do
  use Ecto.Migration

  def change do
    create index(:conversation_participations, ["updated_at desc"])
  end
end
