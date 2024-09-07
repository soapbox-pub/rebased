# Adapted from Akkoma
# https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/priv/repo/migrations/20221129112022_add_cascade_to_report_notes_on_activity_delete.exs

defmodule Pleroma.Repo.Migrations.AddCascadeToReportNotesOnActivityDelete do
  use Ecto.Migration

  def up, do: :ok

  def down do
    drop(constraint(:report_notes, "report_notes_activity_id_fkey"))

    alter table(:report_notes) do
      modify(:activity_id, references(:activities, type: :uuid))
    end
  end
end
