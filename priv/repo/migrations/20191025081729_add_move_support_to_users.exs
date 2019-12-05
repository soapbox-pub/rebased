defmodule Pleroma.Repo.Migrations.AddMoveSupportToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:also_known_as, {:array, :string}, default: [], null: false)
      add(:allow_following_move, :boolean, default: true, null: false)
    end
  end
end
