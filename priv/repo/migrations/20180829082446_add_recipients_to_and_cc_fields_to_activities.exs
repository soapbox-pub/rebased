defmodule Pleroma.Repo.Migrations.AddRecipientsToAndCcFieldsToActivities do
  use Ecto.Migration

  def change do
    alter table(:activities) do
      add(:recipients_to, {:array, :string})
      add(:recipients_cc, {:array, :string})
    end

    create_if_not_exists(index(:activities, [:recipients_to], using: :gin))
    create_if_not_exists(index(:activities, [:recipients_cc], using: :gin))
  end
end
