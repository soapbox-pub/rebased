defmodule Pleroma.Repo.Migrations.FixBlockedFollows do
  use Ecto.Migration

  import Ecto.Query
  alias Pleroma.Config
  alias Pleroma.Repo

  def up do
    unfollow_blocked = Config.get([:activitypub, :unfollow_blocked])

    if unfollow_blocked do
      "activities"
      |> where([activity], fragment("? ->> 'type' = 'Block'", activity.data))
      |> distinct([activity], [
        activity.actor,
        fragment(
          "coalesce((?)->'object'->>'id', (?)->>'object')",
          activity.data,
          activity.data
        )
      ])
      |> order_by([activity], [fragment("? desc nulls last", activity.id)])
      |> select([activity], %{
        blocker: activity.actor,
        blocked:
          fragment("coalesce((?)->'object'->>'id', (?)->>'object')", activity.data, activity.data),
        created_at: activity.id
      })
      |> Repo.stream()
      |> Enum.map(&unfollow_if_blocked/1)
      |> Enum.uniq()
      |> Enum.each(&update_follower_count/1)
    end
  end

  def down do
  end

  def unfollow_if_blocked(%{blocker: blocker_id, blocked: blocked_id, created_at: blocked_at}) do
    query =
      from(
        activity in "activities",
        where: fragment("? ->> 'type' = 'Follow'", activity.data),
        where: activity.actor == ^blocked_id,
        # this is to use the index
        where:
          fragment(
            "coalesce((?)->'object'->>'id', (?)->>'object') = ?",
            activity.data,
            activity.data,
            ^blocker_id
          ),
        where: activity.id > ^blocked_at,
        where: fragment("(?)->>'state' = 'accept'", activity.data),
        order_by: [fragment("? desc nulls last", activity.id)]
      )

    unless Repo.exists?(query) do
      blocker = "users" |> select([:id, :local]) |> Repo.get_by(ap_id: blocker_id)
      blocked = "users" |> select([:id]) |> Repo.get_by(ap_id: blocked_id)

      if !is_nil(blocker) && !is_nil(blocked) do
        unfollow(blocked, blocker)
      end
    end
  end

  def unfollow(%{id: follower_id}, %{id: followed_id} = followed) do
    following_relationship =
      "following_relationships"
      |> where(follower_id: ^follower_id, following_id: ^followed_id, state: "accept")
      |> select([:id])
      |> Repo.one()

    case following_relationship do
      nil ->
        {:ok, nil}

      %{id: following_relationship_id} ->
        "following_relationships"
        |> where(id: ^following_relationship_id)
        |> Repo.delete_all()

        followed
    end
  end

  def update_follower_count(%{id: user_id} = user) do
    if user.local or !Pleroma.Config.get([:instance, :external_user_synchronization]) do
      follower_count_query =
        "users"
        |> where([u], u.id != ^user_id)
        |> where([u], u.deactivated != ^true)
        |> join(:inner, [u], r in "following_relationships",
          as: :relationships,
          on: r.following_id == ^user_id and r.follower_id == u.id
        )
        |> where([relationships: r], r.state == "accept")
        |> select([u], %{count: count(u.id)})

      "users"
      |> where(id: ^user_id)
      |> join(:inner, [u], s in subquery(follower_count_query))
      |> update([u, s],
        set: [follower_count: s.count]
      )
      |> Repo.update_all([])
    end
  end

  def update_follower_count(_), do: :noop
end
