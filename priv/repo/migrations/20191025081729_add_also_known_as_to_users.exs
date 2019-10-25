defmodule Pleroma.Repo.Migrations.AddAlsoKnownAsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:also_known_as, {:array, :string}, default: [])
    end
  end
end
