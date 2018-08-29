defmodule Pleroma.Repo.Migrations.RemoveRecipientsToAndCcFieldsFromActivities do
  use Ecto.Migration

  def change do
    alter table(:activities) do
      remove :recipients_to
      remove :recipients_cc
    end
  end
end
