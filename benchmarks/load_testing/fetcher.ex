defmodule Pleroma.LoadTesting.Fetcher do
  use Pleroma.LoadTesting.Helper

  def fetch_user(user) do
    Benchee.run(%{
      "By id" => fn -> Repo.get_by(User, id: user.id) end,
      "By ap_id" => fn -> Repo.get_by(User, ap_id: user.ap_id) end,
      "By email" => fn -> Repo.get_by(User, email: user.email) end,
      "By nickname" => fn -> Repo.get_by(User, nickname: user.nickname) end
    })
  end

  def query_timelines(user) do
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

    following = User.following(user)

    Benchee.run(%{
      "User home timeline" => fn ->
        Pleroma.Web.ActivityPub.ActivityPub.fetch_activities(
          following,
          home_timeline_params
        )
      end,
      "User mastodon public timeline" => fn ->
        Pleroma.Web.ActivityPub.ActivityPub.fetch_public_activities(
          mastodon_public_timeline_params
        )
      end,
      "User mastodon federated public timeline" => fn ->
        Pleroma.Web.ActivityPub.ActivityPub.fetch_public_activities(
          mastodon_federated_timeline_params
        )
      end
    })

    home_activities =
      Pleroma.Web.ActivityPub.ActivityPub.fetch_activities(
        following,
        home_timeline_params
      )

    public_activities =
      Pleroma.Web.ActivityPub.ActivityPub.fetch_public_activities(mastodon_public_timeline_params)

    public_federated_activities =
      Pleroma.Web.ActivityPub.ActivityPub.fetch_public_activities(
        mastodon_federated_timeline_params
      )

    Benchee.run(%{
      "Rendering home timeline" => fn ->
        Pleroma.Web.MastodonAPI.StatusView.render("index.json", %{
          activities: home_activities,
          for: user,
          as: :activity
        })
      end,
      "Rendering public timeline" => fn ->
        Pleroma.Web.MastodonAPI.StatusView.render("index.json", %{
          activities: public_activities,
          for: user,
          as: :activity
        })
      end,
      "Rendering public federated timeline" => fn ->
        Pleroma.Web.MastodonAPI.StatusView.render("index.json", %{
          activities: public_federated_activities,
          for: user,
          as: :activity
        })
      end,
      "Rendering favorites timeline" => fn ->
        conn = Phoenix.ConnTest.build_conn(:get, "http://localhost:4001/api/v1/favourites", nil)
        Pleroma.Web.MastodonAPI.StatusController.favourites(
          %Plug.Conn{conn |
                     assigns: %{user: user},
                     query_params:  %{"limit" => "0"},
                     body_params: %{},
                     cookies: %{},
                     params: %{},
                     path_params: %{},
                     private: %{
                       Pleroma.Web.Router => {[], %{}},
                       phoenix_router: Pleroma.Web.Router,
                       phoenix_action: :favourites,
                       phoenix_controller: Pleroma.Web.MastodonAPI.StatusController,
                       phoenix_endpoint: Pleroma.Web.Endpoint,
                       phoenix_format: "json",
                       phoenix_layout: {Pleroma.Web.LayoutView, "app.html"},
                       phoenix_recycled: true,

                       phoenix_view: Pleroma.Web.MastodonAPI.StatusView,
                       plug_session: %{"user_id" => user.id},
                       plug_session_fetch: :done,
                       plug_session_info: :write,
                       plug_skip_csrf_protection: true
                     }
          },
          %{})
      end,
    })
  end

  def query_notifications(user) do
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

    without_muted_notifications =
      Pleroma.Web.MastodonAPI.MastodonAPI.get_notifications(user, without_muted_params)

    with_muted_notifications =
      Pleroma.Web.MastodonAPI.MastodonAPI.get_notifications(user, with_muted_params)

    Benchee.run(%{
      "Render notifications without muted" => fn ->
        Pleroma.Web.MastodonAPI.NotificationView.render("index.json", %{
          notifications: without_muted_notifications,
          for: user
        })
      end,
      "Render notifications with muted" => fn ->
        Pleroma.Web.MastodonAPI.NotificationView.render("index.json", %{
          notifications: with_muted_notifications,
          for: user
        })
      end
    })
  end

  def query_dms(user) do
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

    dms_with_muted =
      Pleroma.Web.ActivityPub.ActivityPub.fetch_activities_query([user.ap_id], params)
      |> Pleroma.Pagination.fetch_paginated(params)

    dms_without_muted =
      Pleroma.Web.ActivityPub.ActivityPub.fetch_activities_query([user.ap_id], params)
      |> Pleroma.Pagination.fetch_paginated(Map.put(params, "with_muted", false))

    Benchee.run(%{
      "Rendering dms with muted" => fn ->
        Pleroma.Web.MastodonAPI.StatusView.render("index.json", %{
          activities: dms_with_muted,
          for: user,
          as: :activity
        })
      end,
      "Rendering dms without muted" => fn ->
        Pleroma.Web.MastodonAPI.StatusView.render("index.json", %{
          activities: dms_without_muted,
          for: user,
          as: :activity
        })
      end
    })
  end

  def query_long_thread(user, activity) do
    Benchee.run(%{
      "Fetch main post" => fn ->
        Pleroma.Activity.get_by_id_with_object(activity.id)
      end,
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

    activity = Pleroma.Activity.get_by_id_with_object(activity.id)

    context =
      Pleroma.Web.ActivityPub.ActivityPub.fetch_activities_for_context(
        activity.data["context"],
        %{
          "blocking_user" => user,
          "user" => user,
          "exclude_id" => activity.id
        }
      )

    Benchee.run(%{
      "Render status" => fn ->
        Pleroma.Web.MastodonAPI.StatusView.render("show.json", %{
          activity: activity,
          for: user
        })
      end,
      "Render context" => fn ->
        Pleroma.Web.MastodonAPI.StatusView.render(
          "index.json",
          for: user,
          activities: context,
          as: :activity
        )
        |> Enum.reverse()
      end
    })
  end
end
