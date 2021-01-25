defmodule Pleroma.LoadTesting.Fetcher do
  alias Pleroma.Activity
  alias Pleroma.Pagination
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.MastodonAPI.MastodonAPI
  alias Pleroma.Web.MastodonAPI.StatusView

  @spec run_benchmarks(User.t()) :: any()
  def run_benchmarks(user) do
    fetch_user(user)
    fetch_timelines(user)
    render_views(user)
  end

  defp formatters do
    [
      Benchee.Formatters.Console
    ]
  end

  defp fetch_user(user) do
    Benchee.run(
      %{
        "By id" => fn -> Repo.get_by(User, id: user.id) end,
        "By ap_id" => fn -> Repo.get_by(User, ap_id: user.ap_id) end,
        "By email" => fn -> Repo.get_by(User, email: user.email) end,
        "By nickname" => fn -> Repo.get_by(User, nickname: user.nickname) end
      },
      formatters: formatters()
    )
  end

  defp create_filter(user) do
    Pleroma.Filter.create(%{
      user_id: user.id,
      phrase: "must be filtered",
      hide: true,
      context: ["home"]
    })
  end

  defp delete_filter(filter), do: Repo.delete(filter)

  defp fetch_timelines(user) do
    fetch_home_timeline(user)
    fetch_home_timeline_with_filter(user)
    fetch_direct_timeline(user)
    fetch_public_timeline(user)
    fetch_public_timeline_with_filter(user)
    fetch_public_timeline(user, :with_blocks)
    fetch_public_timeline(user, :local)
    fetch_public_timeline(user, :tag)
    fetch_notifications(user)
    fetch_favourites(user)
    fetch_long_thread(user)
    fetch_timelines_with_reply_filtering(user)
  end

  defp render_views(user) do
    render_timelines(user)
    render_long_thread(user)
  end

  defp opts_for_home_timeline(user) do
    %{
      blocking_user: user,
      count: "20",
      muting_user: user,
      type: ["Create", "Announce"],
      user: user,
      with_muted: true
    }
  end

  defp fetch_home_timeline(user, title_end \\ "") do
    opts = opts_for_home_timeline(user)

    recipients = [user.ap_id | User.following(user)]

    first_page_last =
      ActivityPub.fetch_activities(recipients, opts) |> Enum.reverse() |> List.last()

    second_page_last =
      ActivityPub.fetch_activities(recipients, Map.put(opts, :max_id, first_page_last.id))
      |> Enum.reverse()
      |> List.last()

    third_page_last =
      ActivityPub.fetch_activities(recipients, Map.put(opts, :max_id, second_page_last.id))
      |> Enum.reverse()
      |> List.last()

    forth_page_last =
      ActivityPub.fetch_activities(recipients, Map.put(opts, :max_id, third_page_last.id))
      |> Enum.reverse()
      |> List.last()

    title = "home timeline " <> title_end

    Benchee.run(
      %{
        title => fn opts -> ActivityPub.fetch_activities(recipients, opts) end
      },
      inputs: %{
        "1 page" => opts,
        "2 page" => Map.put(opts, :max_id, first_page_last.id),
        "3 page" => Map.put(opts, :max_id, second_page_last.id),
        "4 page" => Map.put(opts, :max_id, third_page_last.id),
        "5 page" => Map.put(opts, :max_id, forth_page_last.id),
        "1 page only media" => Map.put(opts, :only_media, true),
        "2 page only media" =>
          Map.put(opts, :max_id, first_page_last.id) |> Map.put(:only_media, true),
        "3 page only media" =>
          Map.put(opts, :max_id, second_page_last.id) |> Map.put(:only_media, true),
        "4 page only media" =>
          Map.put(opts, :max_id, third_page_last.id) |> Map.put(:only_media, true),
        "5 page only media" =>
          Map.put(opts, :max_id, forth_page_last.id) |> Map.put(:only_media, true)
      },
      formatters: formatters()
    )
  end

  defp fetch_home_timeline_with_filter(user) do
    {:ok, filter} = create_filter(user)

    fetch_home_timeline(user, "with filters")

    delete_filter(filter)
  end

  defp opts_for_direct_timeline(user) do
    %{
      visibility: "direct",
      blocking_user: user,
      count: "20",
      type: "Create",
      user: user,
      with_muted: true
    }
  end

  defp fetch_direct_timeline(user) do
    recipients = [user.ap_id]

    opts = opts_for_direct_timeline(user)

    first_page_last =
      recipients
      |> ActivityPub.fetch_activities_query(opts)
      |> Pagination.fetch_paginated(opts)
      |> List.last()

    opts2 = Map.put(opts, :max_id, first_page_last.id)

    second_page_last =
      recipients
      |> ActivityPub.fetch_activities_query(opts2)
      |> Pagination.fetch_paginated(opts2)
      |> List.last()

    opts3 = Map.put(opts, :max_id, second_page_last.id)

    third_page_last =
      recipients
      |> ActivityPub.fetch_activities_query(opts3)
      |> Pagination.fetch_paginated(opts3)
      |> List.last()

    opts4 = Map.put(opts, :max_id, third_page_last.id)

    forth_page_last =
      recipients
      |> ActivityPub.fetch_activities_query(opts4)
      |> Pagination.fetch_paginated(opts4)
      |> List.last()

    Benchee.run(
      %{
        "direct timeline" => fn opts ->
          ActivityPub.fetch_activities_query(recipients, opts) |> Pagination.fetch_paginated(opts)
        end
      },
      inputs: %{
        "1 page" => opts,
        "2 page" => opts2,
        "3 page" => opts3,
        "4 page" => opts4,
        "5 page" => Map.put(opts4, :max_id, forth_page_last.id)
      },
      formatters: formatters()
    )
  end

  defp opts_for_public_timeline(user) do
    %{
      type: ["Create", "Announce"],
      local_only: false,
      blocking_user: user,
      muting_user: user
    }
  end

  defp opts_for_public_timeline(user, :local) do
    %{
      type: ["Create", "Announce"],
      local_only: true,
      blocking_user: user,
      muting_user: user
    }
  end

  defp opts_for_public_timeline(user, :tag) do
    %{
      blocking_user: user,
      count: "20",
      local_only: nil,
      muting_user: user,
      tag: ["tag"],
      tag_all: [],
      tag_reject: [],
      type: "Create",
      user: user,
      with_muted: true
    }
  end

  defp fetch_public_timeline(user) do
    opts = opts_for_public_timeline(user)

    fetch_public_timeline(opts, "public timeline")
  end

  defp fetch_public_timeline_with_filter(user) do
    {:ok, filter} = create_filter(user)
    opts = opts_for_public_timeline(user)

    fetch_public_timeline(opts, "public timeline with filters")
    delete_filter(filter)
  end

  defp fetch_public_timeline(user, :local) do
    opts = opts_for_public_timeline(user, :local)

    fetch_public_timeline(opts, "public timeline only local")
  end

  defp fetch_public_timeline(user, :tag) do
    opts = opts_for_public_timeline(user, :tag)

    fetch_public_timeline(opts, "hashtag timeline")
  end

  defp fetch_public_timeline(user, :only_media) do
    opts = opts_for_public_timeline(user) |> Map.put(:only_media, true)

    fetch_public_timeline(opts, "public timeline only media")
  end

  defp fetch_public_timeline(user, :with_blocks) do
    opts = opts_for_public_timeline(user)

    remote_non_friends = Agent.get(:non_friends_remote, & &1)

    Benchee.run(%{
      "public timeline without blocks" => fn ->
        ActivityPub.fetch_public_activities(opts)
      end
    })

    Enum.each(remote_non_friends, fn non_friend ->
      {:ok, _} = User.block(user, non_friend)
    end)

    user = User.get_by_id(user.id)

    opts = Map.put(opts, :blocking_user, user)

    Benchee.run(%{
      "public timeline with user block" => fn ->
        ActivityPub.fetch_public_activities(opts)
      end
    })

    domains =
      Enum.reduce(remote_non_friends, [], fn non_friend, domains ->
        {:ok, _user} = User.unblock(user, non_friend)
        %{host: host} = URI.parse(non_friend.ap_id)
        [host | domains]
      end)

    domains = Enum.uniq(domains)

    Enum.each(domains, fn domain ->
      {:ok, _} = User.block_domain(user, domain)
    end)

    user = User.get_by_id(user.id)
    opts = Map.put(opts, :blocking_user, user)

    Benchee.run(%{
      "public timeline with domain block" => fn ->
        ActivityPub.fetch_public_activities(opts)
      end
    })
  end

  defp fetch_public_timeline(opts, title) when is_binary(title) do
    first_page_last = ActivityPub.fetch_public_activities(opts) |> List.last()

    second_page_last =
      ActivityPub.fetch_public_activities(Map.put(opts, :max_id, first_page_last.id))
      |> List.last()

    third_page_last =
      ActivityPub.fetch_public_activities(Map.put(opts, :max_id, second_page_last.id))
      |> List.last()

    forth_page_last =
      ActivityPub.fetch_public_activities(Map.put(opts, :max_id, third_page_last.id))
      |> List.last()

    Benchee.run(
      %{
        title => fn opts ->
          ActivityPub.fetch_public_activities(opts)
        end
      },
      inputs: %{
        "1 page" => opts,
        "2 page" => Map.put(opts, :max_id, first_page_last.id),
        "3 page" => Map.put(opts, :max_id, second_page_last.id),
        "4 page" => Map.put(opts, :max_id, third_page_last.id),
        "5 page" => Map.put(opts, :max_id, forth_page_last.id)
      },
      formatters: formatters()
    )
  end

  defp opts_for_notifications do
    %{count: "20", with_muted: true}
  end

  defp fetch_notifications(user) do
    opts = opts_for_notifications()

    first_page_last = MastodonAPI.get_notifications(user, opts) |> List.last()

    second_page_last =
      MastodonAPI.get_notifications(user, Map.put(opts, :max_id, first_page_last.id))
      |> List.last()

    third_page_last =
      MastodonAPI.get_notifications(user, Map.put(opts, :max_id, second_page_last.id))
      |> List.last()

    forth_page_last =
      MastodonAPI.get_notifications(user, Map.put(opts, :max_id, third_page_last.id))
      |> List.last()

    Benchee.run(
      %{
        "Notifications" => fn opts ->
          MastodonAPI.get_notifications(user, opts)
        end
      },
      inputs: %{
        "1 page" => opts,
        "2 page" => Map.put(opts, :max_id, first_page_last.id),
        "3 page" => Map.put(opts, :max_id, second_page_last.id),
        "4 page" => Map.put(opts, :max_id, third_page_last.id),
        "5 page" => Map.put(opts, :max_id, forth_page_last.id)
      },
      formatters: formatters()
    )
  end

  defp fetch_favourites(user) do
    first_page_last = ActivityPub.fetch_favourites(user) |> List.last()

    second_page_last =
      ActivityPub.fetch_favourites(user, %{:max_id => first_page_last.id}) |> List.last()

    third_page_last =
      ActivityPub.fetch_favourites(user, %{:max_id => second_page_last.id}) |> List.last()

    forth_page_last =
      ActivityPub.fetch_favourites(user, %{:max_id => third_page_last.id}) |> List.last()

    Benchee.run(
      %{
        "Favourites" => fn opts ->
          ActivityPub.fetch_favourites(user, opts)
        end
      },
      inputs: %{
        "1 page" => %{},
        "2 page" => %{:max_id => first_page_last.id},
        "3 page" => %{:max_id => second_page_last.id},
        "4 page" => %{:max_id => third_page_last.id},
        "5 page" => %{:max_id => forth_page_last.id}
      },
      formatters: formatters()
    )
  end

  defp opts_for_long_thread(user) do
    %{
      blocking_user: user,
      user: user
    }
  end

  defp fetch_long_thread(user) do
    %{public_thread: public, private_thread: private} =
      Agent.get(:benchmark_state, fn state -> state end)

    opts = opts_for_long_thread(user)

    private_input = {private.data["context"], Map.put(opts, :exclude_id, private.id)}

    public_input = {public.data["context"], Map.put(opts, :exclude_id, public.id)}

    Benchee.run(
      %{
        "fetch context" => fn {context, opts} ->
          ActivityPub.fetch_activities_for_context(context, opts)
        end
      },
      inputs: %{
        "Private long thread" => private_input,
        "Public long thread" => public_input
      },
      formatters: formatters()
    )
  end

  defp render_timelines(user) do
    opts = opts_for_home_timeline(user)

    recipients = [user.ap_id | User.following(user)]

    home_activities = ActivityPub.fetch_activities(recipients, opts) |> Enum.reverse()

    recipients = [user.ap_id]

    opts = opts_for_direct_timeline(user)

    direct_activities =
      recipients
      |> ActivityPub.fetch_activities_query(opts)
      |> Pagination.fetch_paginated(opts)

    opts = opts_for_public_timeline(user)

    public_activities = ActivityPub.fetch_public_activities(opts)

    opts = opts_for_public_timeline(user, :tag)

    tag_activities = ActivityPub.fetch_public_activities(opts)

    opts = opts_for_notifications()

    notifications = MastodonAPI.get_notifications(user, opts)

    favourites = ActivityPub.fetch_favourites(user)

    Benchee.run(
      %{
        "Rendering home timeline" => fn ->
          StatusView.render("index.json", %{
            activities: home_activities,
            for: user,
            as: :activity
          })
        end,
        "Rendering direct timeline" => fn ->
          StatusView.render("index.json", %{
            activities: direct_activities,
            for: user,
            as: :activity
          })
        end,
        "Rendering public timeline" => fn ->
          StatusView.render("index.json", %{
            activities: public_activities,
            for: user,
            as: :activity
          })
        end,
        "Rendering tag timeline" => fn ->
          StatusView.render("index.json", %{
            activities: tag_activities,
            for: user,
            as: :activity
          })
        end,
        "Rendering notifications" => fn ->
          Pleroma.Web.MastodonAPI.NotificationView.render("index.json", %{
            notifications: notifications,
            for: user
          })
        end,
        "Rendering favourites timeline" => fn ->
          StatusView.render("index.json", %{
            activities: favourites,
            for: user,
            as: :activity
          })
        end
      },
      formatters: formatters()
    )
  end

  defp render_long_thread(user) do
    %{public_thread: public, private_thread: private} =
      Agent.get(:benchmark_state, fn state -> state end)

    opts = %{for: user}
    public_activity = Activity.get_by_id_with_object(public.id)
    private_activity = Activity.get_by_id_with_object(private.id)

    Benchee.run(
      %{
        "render" => fn opts ->
          StatusView.render("show.json", opts)
        end
      },
      inputs: %{
        "Public root" => Map.put(opts, :activity, public_activity),
        "Private root" => Map.put(opts, :activity, private_activity)
      },
      formatters: formatters()
    )

    fetch_opts = opts_for_long_thread(user)

    public_context =
      ActivityPub.fetch_activities_for_context(
        public.data["context"],
        Map.put(fetch_opts, :exclude_id, public.id)
      )

    private_context =
      ActivityPub.fetch_activities_for_context(
        private.data["context"],
        Map.put(fetch_opts, :exclude_id, private.id)
      )

    Benchee.run(
      %{
        "render" => fn opts ->
          StatusView.render("context.json", opts)
        end
      },
      inputs: %{
        "Public context" => %{user: user, activity: public_activity, activities: public_context},
        "Private context" => %{
          user: user,
          activity: private_activity,
          activities: private_context
        }
      },
      formatters: formatters()
    )
  end

  defp fetch_timelines_with_reply_filtering(user) do
    public_params = opts_for_public_timeline(user)

    Benchee.run(
      %{
        "Public timeline without reply filtering" => fn ->
          ActivityPub.fetch_public_activities(public_params)
        end,
        "Public timeline with reply filtering - following" => fn ->
          public_params
          |> Map.put(:reply_visibility, "following")
          |> Map.put(:reply_filtering_user, user)
          |> ActivityPub.fetch_public_activities()
        end,
        "Public timeline with reply filtering - self" => fn ->
          public_params
          |> Map.put(:reply_visibility, "self")
          |> Map.put(:reply_filtering_user, user)
          |> ActivityPub.fetch_public_activities()
        end
      },
      formatters: formatters()
    )

    private_params = opts_for_home_timeline(user)

    recipients = [user.ap_id | User.following(user)]

    Benchee.run(
      %{
        "Home timeline without reply filtering" => fn ->
          ActivityPub.fetch_activities(recipients, private_params)
        end,
        "Home timeline with reply filtering - following" => fn ->
          private_params =
            private_params
            |> Map.put(:reply_filtering_user, user)
            |> Map.put(:reply_visibility, "following")

          ActivityPub.fetch_activities(recipients, private_params)
        end,
        "Home timeline with reply filtering - self" => fn ->
          private_params =
            private_params
            |> Map.put(:reply_filtering_user, user)
            |> Map.put(:reply_visibility, "self")

          ActivityPub.fetch_activities(recipients, private_params)
        end
      },
      formatters: formatters()
    )
  end
end
