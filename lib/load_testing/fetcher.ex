defmodule Pleroma.LoadTesting.Fetcher do
  use Pleroma.LoadTesting.Helper

  def fetch_user(user) do
    IO.puts("=================================")

    Benchee.run(%{
      "By id" => fn -> Repo.get_by(User, id: user.id) end,
      "By ap_id" => fn -> Repo.get_by(User, ap_id: user.ap_id) end,
      "By email" => fn -> Repo.get_by(User, email: user.email) end,
      "By nickname" => fn -> Repo.get_by(User, nickname: user.nickname) end
    })
  end

  def query_timelines(user) do
    IO.puts("\n=================================")

    home_timeline_params = %{
      "count" => 20,
      "with_muted" => true,
      "type" => ["Create", "Announce"],
      "blocking_user" => user,
      "muting_user" => user,
      "user" => user
    }

    mastodon_public_timeline_params = %{
      "count" => 20,
      "local_only" => true,
      "only_media" => "false",
      "type" => ["Create", "Announce"],
      "with_muted" => "true",
      "blocking_user" => user,
      "muting_user" => user
    }

    mastodon_federated_timeline_params = %{
      "count" => 20,
      "only_media" => "false",
      "type" => ["Create", "Announce"],
      "with_muted" => "true",
      "blocking_user" => user,
      "muting_user" => user
    }

    Benchee.run(%{
      "User home timeline" => fn ->
        Pleroma.Web.ActivityPub.ActivityPub.fetch_activities(
          [user.ap_id | user.following],
          home_timeline_params
        )
      end,
      "User mastodon public timeline" => fn ->
        ActivityPub.ActivityPub.fetch_public_activities(mastodon_public_timeline_params)
      end,
      "User mastodon federated public timeline" => fn ->
        ActivityPub.ActivityPub.fetch_public_activities(mastodon_federated_timeline_params)
      end
    })
  end

  def query_notifications(user) do
    IO.puts("\n=================================")
    without_muted_params = %{"count" => "20", "with_muted" => "false"}
    with_muted_params = %{"count" => "20", "with_muted" => "true"}

    Benchee.run(%{
      "Notifications without muted" => fn ->
        Pleroma.Web.MastodonAPI.MastodonAPI.get_notifications(user, without_muted_params)
      end,
      "Notifications with muted" => fn ->
        Pleroma.Web.MastodonAPI.MastodonAPI.get_notifications(user, with_muted_params)
      end
    })
  end

  def query_dms(user) do
    IO.puts("\n=================================")

    params = %{
      "count" => "20",
      "with_muted" => "true",
      "type" => "Create",
      "blocking_user" => user,
      "user" => user,
      visibility: "direct"
    }

    Benchee.run(%{
      "Direct messages with muted" => fn ->
        Pleroma.Web.ActivityPub.ActivityPub.fetch_activities_query([user.ap_id], params)
        |> Pleroma.Pagination.fetch_paginated(params)
      end,
      "Direct messages without muted" => fn ->
        Pleroma.Web.ActivityPub.ActivityPub.fetch_activities_query([user.ap_id], params)
        |> Pleroma.Pagination.fetch_paginated(Map.put(params, "with_muted", false))
      end
    })
  end

  def query_long_thread(user, activity) do
    IO.puts("\n=================================")

    Benchee.run(%{
      "Fetch main post" => fn -> Activity.get_by_id_with_object(activity.id) end,
      "Fetch context of main post" => fn ->
        Pleroma.Web.ActivityPub.ActivityPub.fetch_activities_for_context(
          activity.data["context"],
          %{
            "blocking_user" => user,
            "user" => user,
            "exclude_id" => activity.id
          }
        )
      end
    })
  end
end
