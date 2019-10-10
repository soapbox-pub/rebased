defmodule Pleroma.Repo.Migrations.RemoveRecipientsToAndCcFieldsFromActivities do
  use Ecto.Migration

  def up do
    alter table(:activities) do
      remove(:recipients_to)
      remove(:recipients_cc)
    end
  end

  def down do
    alter table(:activities) do
      add(:recipients_to, {:array, :string})
      add(:recipients_cc, {:array, :string})
    end
  end
end
