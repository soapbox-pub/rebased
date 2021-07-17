defmodule Pleroma.LoadTesting.Activities do
  @moduledoc """
  Module for generating different activities.
  """
  import Ecto.Query
  import Pleroma.LoadTesting.Helper, only: [to_sec: 1]

  alias Ecto.UUID
  alias Pleroma.Constants
  alias Pleroma.LoadTesting.Users
  alias Pleroma.Repo
  alias Pleroma.Web.CommonAPI

  require Constants

  @defaults [
    iterations: 170,
    friends_used: 20,
    non_friends_used: 20
  ]

  @max_concurrency 10

  @visibility ~w(public private direct unlisted)
  @types [
    :simple,
    :simple_filtered,
    :emoji,
    :mentions,
    :hell_thread,
    :attachment,
    :tag,
    :like,
    :reblog,
    :simple_thread
  ]
  @groups [:friends_local, :friends_remote, :non_friends_local, :non_friends_local]
  @remote_groups [:friends_remote, :non_friends_remote]
  @friends_groups [:friends_local, :friends_remote]
  @non_friends_groups [:non_friends_local, :non_friends_remote]

  @spec generate(User.t(), keyword()) :: :ok
  def generate(user, opts \\ []) do
    {:ok, _} =
      Agent.start_link(fn -> %{} end,
        name: :benchmark_state
      )

    opts = Keyword.merge(@defaults, opts)

    users = Users.prepare_users(user, opts)

    {:ok, _} = Agent.start_link(fn -> users[:non_friends_remote] end, name: :non_friends_remote)

    task_data =
      for visibility <- @visibility,
          type <- @types,
          group <- [:user | @groups],
          do: {visibility, type, group}

    IO.puts("Starting generating #{opts[:iterations]} iterations of activities...")

    public_long_thread = fn ->
      generate_long_thread("public", users, opts)
    end

    private_long_thread = fn ->
      generate_long_thread("private", users, opts)
    end

    iterations = opts[:iterations]

    {time, _} =
      :timer.tc(fn ->
        Enum.each(
          1..iterations,
          fn
            i when i == iterations - 2 ->
              spawn(public_long_thread)
              spawn(private_long_thread)
              generate_activities(users, Enum.shuffle(task_data), opts)

            _ ->
              generate_activities(users, Enum.shuffle(task_data), opts)
          end
        )
      end)

    IO.puts("Generating iterations of activities took #{to_sec(time)} sec.\n")
    :ok
  end

  def generate_power_intervals(opts \\ []) do
    count = Keyword.get(opts, :count, 20)
    power = Keyword.get(opts, :power, 2)
    IO.puts("Generating #{count} intervals for a power #{power} series...")
    counts = Enum.map(1..count, fn n -> :math.pow(n, power) end)
    sum = Enum.sum(counts)

    densities =
      Enum.map(counts, fn c ->
        c / sum
      end)

    densities
    |> Enum.reduce(0, fn density, acc ->
      if acc == 0 do
        [{0, density}]
      else
        [{_, lower} | _] = acc
        [{lower, lower + density} | acc]
      end
    end)
    |> Enum.reverse()
  end

  def generate_tagged_activities(opts \\ []) do
    tag_count = Keyword.get(opts, :tag_count, 20)
    users = Keyword.get(opts, :users, Repo.all(Pleroma.User))
    activity_count = Keyword.get(opts, :count, 200_000)

    intervals = generate_power_intervals(count: tag_count)

    IO.puts(
      "Generating #{activity_count} activities using #{tag_count} different tags of format `tag_n`, starting at tag_0"
    )

    Enum.each(1..activity_count, fn _ ->
      random = :rand.uniform()
      i = Enum.find_index(intervals, fn {lower, upper} -> lower <= random && upper > random end)
      CommonAPI.post(Enum.random(users), %{status: "a post with the tag #tag_#{i}"})
    end)
  end

  defp generate_long_thread(visibility, users, _opts) do
    group =
      if visibility == "public",
        do: :friends_local,
        else: :user

    tasks = get_reply_tasks(visibility, group) |> Stream.cycle() |> Enum.take(50)

    {:ok, activity} =
      CommonAPI.post(users[:user], %{
        status: "Start of #{visibility} long thread",
        visibility: visibility
      })

    Agent.update(:benchmark_state, fn state ->
      key =
        if visibility == "public",
          do: :public_thread,
          else: :private_thread

      Map.put(state, key, activity)
    end)

    acc = {activity.id, ["@" <> users[:user].nickname, "reply to long thread"]}
    insert_replies_for_long_thread(tasks, visibility, users, acc)
    IO.puts("Generating #{visibility} long thread ended\n")
  end

  defp insert_replies_for_long_thread(tasks, visibility, users, acc) do
    Enum.reduce(tasks, acc, fn
      :user, {id, data} ->
        user = users[:user]
        insert_reply(user, List.delete(data, "@" <> user.nickname), id, visibility)

      group, {id, data} ->
        replier = Enum.random(users[group])
        insert_reply(replier, List.delete(data, "@" <> replier.nickname), id, visibility)
    end)
  end

  defp generate_activities(users, task_data, opts) do
    Task.async_stream(
      task_data,
      fn {visibility, type, group} ->
        insert_activity(type, visibility, group, users, opts)
      end,
      max_concurrency: @max_concurrency,
      timeout: 30_000
    )
    |> Stream.run()
  end

  defp insert_local_activity(visibility, group, users, status) do
    {:ok, _} =
      group
      |> get_actor(users)
      |> CommonAPI.post(%{status: status, visibility: visibility})
  end

  defp insert_remote_activity(visibility, group, users, status) do
    actor = get_actor(group, users)
    {act_data, obj_data} = prepare_activity_data(actor, visibility, users[:user])
    {activity_data, object_data} = other_data(actor, status)

    activity_data
    |> Map.merge(act_data)
    |> Map.put("object", Map.merge(object_data, obj_data))
    |> Pleroma.Web.ActivityPub.ActivityPub.insert(false)
  end

  defp user_mentions(users) do
    user_mentions =
      Enum.reduce(
        @groups,
        [],
        fn group, acc ->
          acc ++ get_random_mentions(users[group], Enum.random(0..2))
        end
      )

    if Enum.random([true, false]),
      do: ["@" <> users[:user].nickname | user_mentions],
      else: user_mentions
  end

  defp hell_thread_mentions(users) do
    with {:ok, nil} <- Cachex.get(:user_cache, "hell_thread_mentions") do
      cached =
        @groups
        |> Enum.reduce([users[:user]], fn group, acc ->
          acc ++ Enum.take(users[group], 5)
        end)
        |> Enum.map(&"@#{&1.nickname}")
        |> Enum.join(", ")

      Cachex.put(:user_cache, "hell_thread_mentions", cached)
      cached
    else
      {:ok, cached} -> cached
    end
  end

  defp insert_activity(:simple, visibility, group, users, _opts)
       when group in @remote_groups do
    insert_remote_activity(visibility, group, users, "Remote status")
  end

  defp insert_activity(:simple, visibility, group, users, _opts) do
    insert_local_activity(visibility, group, users, "Simple status")
  end

  defp insert_activity(:simple_filtered, visibility, group, users, _opts)
       when group in @remote_groups do
    insert_remote_activity(visibility, group, users, "Remote status which must be filtered")
  end

  defp insert_activity(:simple_filtered, visibility, group, users, _opts) do
    insert_local_activity(visibility, group, users, "Simple status which must be filtered")
  end

  defp insert_activity(:emoji, visibility, group, users, _opts)
       when group in @remote_groups do
    insert_remote_activity(visibility, group, users, "Remote status with emoji :firefox:")
  end

  defp insert_activity(:emoji, visibility, group, users, _opts) do
    insert_local_activity(visibility, group, users, "Simple status with emoji :firefox:")
  end

  defp insert_activity(:mentions, visibility, group, users, _opts)
       when group in @remote_groups do
    mentions = user_mentions(users)

    status = Enum.join(mentions, ", ") <> " remote status with mentions"

    insert_remote_activity(visibility, group, users, status)
  end

  defp insert_activity(:mentions, visibility, group, users, _opts) do
    mentions = user_mentions(users)

    status = Enum.join(mentions, ", ") <> " simple status with mentions"
    insert_remote_activity(visibility, group, users, status)
  end

  defp insert_activity(:hell_thread, visibility, group, users, _)
       when group in @remote_groups do
    mentions = hell_thread_mentions(users)
    insert_remote_activity(visibility, group, users, mentions <> " remote hell thread status")
  end

  defp insert_activity(:hell_thread, visibility, group, users, _opts) do
    mentions = hell_thread_mentions(users)

    insert_local_activity(visibility, group, users, mentions <> " hell thread status")
  end

  defp insert_activity(:attachment, visibility, group, users, _opts) do
    actor = get_actor(group, users)

    obj_data = %{
      "actor" => actor.ap_id,
      "name" => "4467-11.jpg",
      "type" => "Document",
      "url" => [
        %{
          "href" =>
            "#{Pleroma.Web.Endpoint.url()}/media/b1b873552422a07bf53af01f3c231c841db4dfc42c35efde681abaf0f2a4eab7.jpg",
          "mediaType" => "image/jpeg",
          "type" => "Link"
        }
      ]
    }

    object = Repo.insert!(%Pleroma.Object{data: obj_data})

    {:ok, _activity} =
      CommonAPI.post(actor, %{
        status: "Post with attachment",
        visibility: visibility,
        media_ids: [object.id]
      })
  end

  defp insert_activity(:tag, visibility, group, users, _opts) do
    insert_local_activity(visibility, group, users, "Status with #tag")
  end

  defp insert_activity(:like, visibility, group, users, opts) do
    actor = get_actor(group, users)

    with activity_id when not is_nil(activity_id) <- get_random_create_activity_id(),
         {:ok, _activity} <- CommonAPI.favorite(actor, activity_id) do
      :ok
    else
      {:error, _} ->
        insert_activity(:like, visibility, group, users, opts)

      nil ->
        Process.sleep(15)
        insert_activity(:like, visibility, group, users, opts)
    end
  end

  defp insert_activity(:reblog, visibility, group, users, opts) do
    actor = get_actor(group, users)

    with activity_id when not is_nil(activity_id) <- get_random_create_activity_id(),
         {:ok, _activity} <- CommonAPI.repeat(activity_id, actor) do
      :ok
    else
      {:error, _} ->
        insert_activity(:reblog, visibility, group, users, opts)

      nil ->
        Process.sleep(15)
        insert_activity(:reblog, visibility, group, users, opts)
    end
  end

  defp insert_activity(:simple_thread, "direct", group, users, _opts) do
    actor = get_actor(group, users)
    tasks = get_reply_tasks("direct", group)

    list =
      case group do
        :user ->
          group = Enum.random(@friends_groups)
          Enum.take(users[group], 3)

        _ ->
          Enum.take(users[group], 3)
      end

    data = Enum.map(list, &("@" <> &1.nickname))

    {:ok, activity} =
      CommonAPI.post(actor, %{
        status: Enum.join(data, ", ") <> "simple status",
        visibility: "direct"
      })

    acc = {activity.id, ["@" <> users[:user].nickname | data] ++ ["reply to status"]}
    insert_direct_replies(tasks, users[:user], list, acc)
  end

  defp insert_activity(:simple_thread, visibility, group, users, _opts) do
    actor = get_actor(group, users)
    tasks = get_reply_tasks(visibility, group)

    {:ok, activity} =
      CommonAPI.post(users[:user], %{status: "Simple status", visibility: visibility})

    acc = {activity.id, ["@" <> actor.nickname, "reply to status"]}
    insert_replies(tasks, visibility, users, acc)
  end

  defp get_actor(:user, %{user: user}), do: user
  defp get_actor(group, users), do: Enum.random(users[group])

  defp other_data(actor, content) do
    %{host: host} = URI.parse(actor.ap_id)
    datetime = DateTime.utc_now()
    context_id = "https://#{host}/contexts/#{UUID.generate()}"
    activity_id = "https://#{host}/activities/#{UUID.generate()}"
    object_id = "https://#{host}/objects/#{UUID.generate()}"

    activity_data = %{
      "actor" => actor.ap_id,
      "context" => context_id,
      "id" => activity_id,
      "published" => datetime,
      "type" => "Create",
      "directMessage" => false
    }

    object_data = %{
      "actor" => actor.ap_id,
      "attachment" => [],
      "attributedTo" => actor.ap_id,
      "bcc" => [],
      "bto" => [],
      "content" => content,
      "context" => context_id,
      "conversation" => context_id,
      "emoji" => %{},
      "id" => object_id,
      "published" => datetime,
      "sensitive" => false,
      "summary" => "",
      "tag" => [],
      "to" => ["https://www.w3.org/ns/activitystreams#Public"],
      "type" => "Note"
    }

    {activity_data, object_data}
  end

  defp prepare_activity_data(actor, "public", _mention) do
    obj_data = %{
      "cc" => [actor.follower_address],
      "to" => [Constants.as_public()]
    }

    act_data = %{
      "cc" => [actor.follower_address],
      "to" => [Constants.as_public()]
    }

    {act_data, obj_data}
  end

  defp prepare_activity_data(actor, "private", _mention) do
    obj_data = %{
      "cc" => [],
      "to" => [actor.follower_address]
    }

    act_data = %{
      "cc" => [],
      "to" => [actor.follower_address]
    }

    {act_data, obj_data}
  end

  defp prepare_activity_data(actor, "unlisted", _mention) do
    obj_data = %{
      "cc" => [Constants.as_public()],
      "to" => [actor.follower_address]
    }

    act_data = %{
      "cc" => [Constants.as_public()],
      "to" => [actor.follower_address]
    }

    {act_data, obj_data}
  end

  defp prepare_activity_data(_actor, "direct", mention) do
    %{host: mentioned_host} = URI.parse(mention.ap_id)

    obj_data = %{
      "cc" => [],
      "content" =>
        "<span class=\"h-card\"><a class=\"u-url mention\" href=\"#{mention.ap_id}\" rel=\"ugc\">@<span>#{
          mention.nickname
        }</span></a></span> direct message",
      "tag" => [
        %{
          "href" => mention.ap_id,
          "name" => "@#{mention.nickname}@#{mentioned_host}",
          "type" => "Mention"
        }
      ],
      "to" => [mention.ap_id]
    }

    act_data = %{
      "cc" => [],
      "directMessage" => true,
      "to" => [mention.ap_id]
    }

    {act_data, obj_data}
  end

  defp get_reply_tasks("public", :user) do
    [:friends_local, :friends_remote, :non_friends_local, :non_friends_remote, :user]
  end

  defp get_reply_tasks("public", group) when group in @friends_groups do
    [:non_friends_local, :non_friends_remote, :user, :friends_local, :friends_remote]
  end

  defp get_reply_tasks("public", group) when group in @non_friends_groups do
    [:user, :friends_local, :friends_remote, :non_friends_local, :non_friends_remote]
  end

  defp get_reply_tasks(visibility, :user) when visibility in ["unlisted", "private"] do
    [:friends_local, :friends_remote, :user, :friends_local, :friends_remote]
  end

  defp get_reply_tasks(visibility, group)
       when visibility in ["unlisted", "private"] and group in @friends_groups do
    [:user, :friends_remote, :friends_local, :user]
  end

  defp get_reply_tasks(visibility, group)
       when visibility in ["unlisted", "private"] and
              group in @non_friends_groups,
       do: []

  defp get_reply_tasks("direct", :user), do: [:friends_local, :user, :friends_remote]

  defp get_reply_tasks("direct", group) when group in @friends_groups,
    do: [:user, group, :user]

  defp get_reply_tasks("direct", group) when group in @non_friends_groups do
    [:user, :non_friends_remote, :user, :non_friends_local]
  end

  defp insert_replies(tasks, visibility, users, acc) do
    Enum.reduce(tasks, acc, fn
      :user, {id, data} ->
        insert_reply(users[:user], data, id, visibility)

      group, {id, data} ->
        replier = Enum.random(users[group])
        insert_reply(replier, data, id, visibility)
    end)
  end

  defp insert_direct_replies(tasks, user, list, acc) do
    Enum.reduce(tasks, acc, fn
      :user, {id, data} ->
        {reply_id, _} = insert_reply(user, List.delete(data, "@" <> user.nickname), id, "direct")
        {reply_id, data}

      _, {id, data} ->
        actor = Enum.random(list)

        {reply_id, _} =
          insert_reply(actor, List.delete(data, "@" <> actor.nickname), id, "direct")

        {reply_id, data}
    end)
  end

  defp insert_reply(actor, data, activity_id, visibility) do
    {:ok, reply} =
      CommonAPI.post(actor, %{
        status: Enum.join(data, ", "),
        visibility: visibility,
        in_reply_to_status_id: activity_id
      })

    {reply.id, ["@" <> actor.nickname | data]}
  end

  defp get_random_mentions(_users, count) when count == 0, do: []

  defp get_random_mentions(users, count) do
    users
    |> Enum.shuffle()
    |> Enum.take(count)
    |> Enum.map(&"@#{&1.nickname}")
  end

  defp get_random_create_activity_id do
    Repo.one(
      from(a in Pleroma.Activity,
        where: fragment("(?)->>'type' = ?", a.data, ^"Create"),
        order_by: fragment("RANDOM()"),
        limit: 1,
        select: a.id
      )
    )
  end
end
