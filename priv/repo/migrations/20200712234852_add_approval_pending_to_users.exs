defmodule Pleroma.Repo.Migrations.AddApprovalPendingToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:approval_pending, :boolean)
    end
  end
end
