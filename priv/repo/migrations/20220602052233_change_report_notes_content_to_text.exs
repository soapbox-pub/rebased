defmodule Pleroma.Repo.Migrations.ChangeReportNotesContentToText do
  use Ecto.Migration

  def up do
    alter table(:report_notes) do
      modify(:content, :text)
    end
  end

  # 20191203043610_create_report_notes.exs
  def down do
    alter table(:report_notes) do
      modify(:content, :string)
    end
  end
end
