defmodule Pleroma.Repo.Migrations.AddApprovalFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:approval_pending, :boolean)
      add(:registration_reason, :text)
    end
  end
end
