defmodule Pleroma.Repo.Migrations.RemoveUnreadConversationCountFromUser do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.Repo

  def up do
    alter table(:users) do
      remove_if_exists(:unread_conversation_count, :integer)
    end
  end

  def down do
    alter table(:users) do
      add_if_not_exists(:unread_conversation_count, :integer, default: 0)
    end

    flush()
    recalc_unread_conversation_count()
  end

  defp recalc_unread_conversation_count do
    participations_subquery =
      from(
        p in "conversation_participations",
        where: p.read == false,
        group_by: p.user_id,
        select: %{user_id: p.user_id, unread_conversation_count: count(p.id)}
      )

    from(
      u in "users",
      join: p in subquery(participations_subquery),
      on: p.user_id == u.id,
      update: [set: [unread_conversation_count: p.unread_conversation_count]]
    )
    |> Repo.update_all([])
  end
end
