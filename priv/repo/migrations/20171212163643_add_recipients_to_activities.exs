defmodule Pleroma.Repo.Migrations.AddRecipientsToActivities do
  use Ecto.Migration

  def change do
    alter table(:activities) do
      add(:recipients, {:array, :string})
    end

    create_if_not_exists(index(:activities, [:recipients], using: :gin))
  end
end
