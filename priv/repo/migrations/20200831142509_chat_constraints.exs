defmodule Pleroma.Repo.Migrations.ChatConstraints do
  use Ecto.Migration

  def change do
    remove_orphans = """
    delete from chats where not exists(select id from users where ap_id = chats.recipient);
    """

    execute(remove_orphans)

    drop(constraint(:chats, "chats_user_id_fkey"))

    alter table(:chats) do
      modify(:user_id, references(:users, type: :uuid, on_delete: :delete_all))

      modify(
        :recipient,
        references(:users, column: :ap_id, type: :string, on_delete: :delete_all)
      )
    end
  end
end
