defmodule Pleroma.Repo.Migrations.AddRegistrationReasonToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:registration_reason, :string)
    end
  end
end
