defmodule Pleroma.Repo.Migrations.MakeFollowingPostgresArray do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :following_temp, {:array, :string}
    end

    execute """
    update users set following_temp = array(select jsonb_array_elements_text(following));
    """

    alter table(:users) do
      remove :following
    end
    rename table(:users), :following_temp, to: :following
  end
end
