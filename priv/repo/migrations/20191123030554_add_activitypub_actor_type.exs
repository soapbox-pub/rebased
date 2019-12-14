defmodule Pleroma.Repo.Migrations.AddActivitypubActorType do
  use Ecto.Migration

  def change do
    alter table("users") do
      add(:actor_type, :string, null: false, default: "Person")
    end
  end
end
