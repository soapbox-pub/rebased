defmodule Pleroma.Repo.Migrations.AddPrivacyFieldToGroups do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      add(:privacy, :string, default: "public")
    end
  end
end
