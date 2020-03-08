defmodule Pleroma.Repo.Migrations.CreateReportNotes do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:report_notes) do
      add(:user_id, references(:users, type: :uuid))
      add(:activity_id, references(:activities, type: :uuid))
      add(:content, :string)

      timestamps()
    end
  end
end
