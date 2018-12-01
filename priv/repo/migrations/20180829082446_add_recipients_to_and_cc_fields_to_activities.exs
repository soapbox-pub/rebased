defmodule Pleroma.Repo.Migrations.AddRecipientsToAndCcFieldsToActivities do
  use Ecto.Migration

  def change do
    alter table(:activities) do
      add :recipients_to, {:array, :string}
      add :recipients_cc, {:array, :string}
    end

    create index(:activities, [:recipients_to], using: :gin)
    create index(:activities, [:recipients_cc], using: :gin)
  end
end
