defmodule Pleroma.Repo.Migrations.AddActivityAssignedAccountIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(
      index(:activities, ["(data->>'assigned_account')"], name: :activities_assigned_account_index)
    )
  end
end
