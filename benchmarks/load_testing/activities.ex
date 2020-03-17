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
  @types ~w(simple emoji mentions hell_thread attachment tag like reblog simple_thread remote)
  @groups ~w(user friends non_friends)

  @spec generate(User.t(), keyword()) :: :ok
  def generate(user, opts \\ []) do
    {:ok, _} =
      Agent.start_link(fn -> %{} end,
        name: :benchmark_state
      )

    opts = Keyword.merge(@defaults, opts)

    friends =
      user
      |> Users.get_users(limit: opts[:friends_used], local: :local, friends?: true)
      |> Enum.shuffle()

    non_friends =
      user
      |> Users.get_users(limit: opts[:non_friends_used], local: :local, friends?: false)
      |> Enum.shuffle()

    task_data =
      for visibility <- @visibility,
          type <- @types,
          group <- @groups,
          do: {visibility, type, group}

    IO.puts("Starting generating #{opts[:iterations]} iterations of activities...")

    friends_thread = Enum.take(friends, 5)
    non_friends_thread = Enum.take(friends, 5)

    public_long_thread = fn ->
      generate_long_thread("public", user, friends_thread, non_friends_thread, opts)
    end

    private_long_thread = fn ->
      generate_long_thread("private", user, friends_thread, non_friends_thread, opts)
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
              generate_activities(user, friends, non_friends, Enum.shuffle(task_data), opts)

            _ ->
              generate_activities(user, friends, non_friends, Enum.shuffle(task_data), opts)
          end
        )
      end)

    IO.puts("Generating iterations of activities take #{to_sec(time)} sec.\n")
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
      CommonAPI.post(Enum.random(users), %{"status" => "a post with the tag #tag_#{i}"})
    end)
  end

  defp generate_long_thread(visibility, user, friends, non_friends, _opts) do
    group =
      if visibility == "public",
        do: "friends",
        else: "user"

    tasks = get_reply_tasks(visibility, group) |> Stream.cycle() |> Enum.take(50)

    {:ok, activity} =
      CommonAPI.post(user, %{
        "status" => "Start of #{visibility} long thread",
        "visibility" => visibility
      })

    Agent.update(:benchmark_state, fn state ->
      key =
        if visibility == "public",
          do: :public_thread,
          else: :private_thread

      Map.put(state, key, activity)
    end)

    acc = {activity.id, ["@" <> user.nickname, "reply to long thread"]}
    insert_replies_for_long_thread(tasks, visibility, user, friends, non_friends, acc)
    IO.puts("Generating #{visibility} long thread ended\n")
  end

  defp insert_replies_for_long_thread(tasks, visibility, user, friends, non_friends, acc) do
    Enum.reduce(tasks, acc, fn
      "friend", {id, data} ->
        friend = Enum.random(friends)
        insert_reply(friend, List.delete(data, "@" <> friend.nickname), id, visibility)

      "non_friend", {id, data} ->
        non_friend = Enum.random(non_friends)
        insert_reply(non_friend, List.delete(data, "@" <> non_friend.nickname), id, visibility)

      "user", {id, data} ->
        insert_reply(user, List.delete(data, "@" <> user.nickname), id, visibility)
    end)
  end

  defp generate_activities(user, friends, non_friends, task_data, opts) do
    Task.async_stream(
      task_data,
      fn {visibility, type, group} ->
        insert_activity(type, visibility, group, user, friends, non_friends, opts)
      end,
      max_concurrency: @max_concurrency,
      timeout: 30_000
    )
    |> Stream.run()
  end

  defp insert_activity("simple", visibility, group, user, friends, non_friends, _opts) do
    {:ok, _activity} =
      group
      |> get_actor(user, friends, non_friends)
      |> CommonAPI.post(%{"status" => "Simple status", "visibility" => visibility})
  end

  defp insert_activity("emoji", visibility, group, user, friends, non_friends, _opts) do
    {:ok, _activity} =
      group
      |> get_actor(user, friends, non_friends)
      |> CommonAPI.post(%{
        "status" => "Simple status with emoji :firefox:",
        "visibility" => visibility
      })
  end

  defp insert_activity("mentions", visibility, group, user, friends, non_friends, _opts) do
    user_mentions =
      get_random_mentions(friends, Enum.random(0..3)) ++
        get_random_mentions(non_friends, Enum.random(0..3))

    user_mentions =
      if Enum.random([true, false]),
        do: ["@" <> user.nickname | user_mentions],
        else: user_mentions

    {:ok, _activity} =
      group
      |> get_actor(user, friends, non_friends)
      |> CommonAPI.post(%{
        "status" => Enum.join(user_mentions, ", ") <> " simple status with mentions",
        "visibility" => visibility
      })
  end

  defp insert_activity("hell_thread", visibility, group, user, friends, non_friends, _opts) do
    mentions =
      with {:ok, nil} <- Cachex.get(:user_cache, "hell_thread_mentions") do
        cached =
          ([user | Enum.take(friends, 10)] ++ Enum.take(non_friends, 10))
          |> Enum.map(&"@#{&1.nickname}")
          |> Enum.join(", ")

        Cachex.put(:user_cache, "hell_thread_mentions", cached)
        cached
      else
        {:ok, cached} -> cached
      end

    {:ok, _activity} =
      group
      |> get_actor(user, friends, non_friends)
      |> CommonAPI.post(%{
        "status" => mentions <> " hell thread status",
        "visibility" => visibility
      })
  end

  defp insert_activity("attachment", visibility, group, user, friends, non_friends, _opts) do
    actor = get_actor(group, user, friends, non_friends)

    obj_data = %{
      "actor" => actor.ap_id,
      "name" => "4467-11.jpg",
      "type" => "Document",
      "url" => [
        %{
          "href" =>
            "#{Pleroma.Web.base_url()}/media/b1b873552422a07bf53af01f3c231c841db4dfc42c35efde681abaf0f2a4eab7.jpg",
          "mediaType" => "image/jpeg",
          "type" => "Link"
        }
      ]
    }

    object = Repo.insert!(%Pleroma.Object{data: obj_data})

    {:ok, _activity} =
      CommonAPI.post(actor, %{
        "status" => "Post with attachment",
        "visibility" => visibility,
        "media_ids" => [object.id]
      })
  end

  defp insert_activity("tag", visibility, group, user, friends, non_friends, _opts) do
    {:ok, _activity} =
      group
      |> get_actor(user, friends, non_friends)
      |> CommonAPI.post(%{"status" => "Status with #tag", "visibility" => visibility})
  end

  defp insert_activity("like", visibility, group, user, friends, non_friends, opts) do
    actor = get_actor(group, user, friends, non_friends)

    with activity_id when not is_nil(activity_id) <- get_random_create_activity_id(),
         {:ok, _activity, _object} <- CommonAPI.favorite(activity_id, actor) do
      :ok
    else
      {:error, _} ->
        insert_activity("like", visibility, group, user, friends, non_friends, opts)

      nil ->
        Process.sleep(15)
        insert_activity("like", visibility, group, user, friends, non_friends, opts)
    end
  end

  defp insert_activity("reblog", visibility, group, user, friends, non_friends, opts) do
    actor = get_actor(group, user, friends, non_friends)

    with activity_id when not is_nil(activity_id) <- get_random_create_activity_id(),
         {:ok, _activity, _object} <- CommonAPI.repeat(activity_id, actor) do
      :ok
    else
      {:error, _} ->
        insert_activity("reblog", visibility, group, user, friends, non_friends, opts)

      nil ->
        Process.sleep(15)
        insert_activity("reblog", visibility, group, user, friends, non_friends, opts)
    end
  end

  defp insert_activity("simple_thread", visibility, group, user, friends, non_friends, _opts)
       when visibility in ["public", "unlisted", "private"] do
    actor = get_actor(group, user, friends, non_friends)
    tasks = get_reply_tasks(visibility, group)

    {:ok, activity} =
      CommonAPI.post(user, %{"status" => "Simple status", "visibility" => "unlisted"})

    acc = {activity.id, ["@" <> actor.nickname, "reply to status"]}
    insert_replies(tasks, visibility, user, friends, non_friends, acc)
  end

  defp insert_activity("simple_thread", "direct", group, user, friends, non_friends, _opts) do
    actor = get_actor(group, user, friends, non_friends)
    tasks = get_reply_tasks("direct", group)

    list =
      case group do
        "non_friends" ->
          Enum.take(non_friends, 3)

        _ ->
          Enum.take(friends, 3)
      end

    data = Enum.map(list, &("@" <> &1.nickname))

    {:ok, activity} =
      CommonAPI.post(actor, %{
        "status" => Enum.join(data, ", ") <> "simple status",
        "visibility" => "direct"
      })

    acc = {activity.id, ["@" <> user.nickname | data] ++ ["reply to status"]}
    insert_direct_replies(tasks, user, list, acc)
  end

  defp insert_activity("remote", _, "user", _, _, _, _), do: :ok

  defp insert_activity("remote", visibility, group, user, _friends, _non_friends, opts) do
    remote_friends =
      Users.get_users(user, limit: opts[:friends_used], local: :external, friends?: true)

    remote_non_friends =
      Users.get_users(user, limit: opts[:non_friends_used], local: :external, friends?: false)

    actor = get_actor(group, user, remote_friends, remote_non_friends)

    {act_data, obj_data} = prepare_activity_data(actor, visibility, user)
    {activity_data, object_data} = other_data(actor)

    activity_data
    |> Map.merge(act_data)
    |> Map.put("object", Map.merge(object_data, obj_data))
    |> Pleroma.Web.ActivityPub.ActivityPub.insert(false)
  end

  defp get_actor("user", user, _friends, _non_friends), do: user
  defp get_actor("friends", _user, friends, _non_friends), do: Enum.random(friends)
  defp get_actor("non_friends", _user, _friends, non_friends), do: Enum.random(non_friends)

  defp other_data(actor) do
    %{host: host} = URI.parse(actor.ap_id)
    datetime = DateTime.utc_now()
    context_id = "http://#{host}:4000/contexts/#{UUID.generate()}"
    activity_id = "http://#{host}:4000/activities/#{UUID.generate()}"
    object_id = "http://#{host}:4000/objects/#{UUID.generate()}"

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
      "content" => "Remote post",
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

  defp get_reply_tasks("public", "user"), do: ~w(friend non_friend user)
  defp get_reply_tasks("public", "friends"), do: ~w(non_friend user friend)
  defp get_reply_tasks("public", "non_friends"), do: ~w(user friend non_friend)

  defp get_reply_tasks(visibility, "user") when visibility in ["unlisted", "private"],
    do: ~w(friend user friend)

  defp get_reply_tasks(visibility, "friends") when visibility in ["unlisted", "private"],
    do: ~w(user friend user)

  defp get_reply_tasks(visibility, "non_friends") when visibility in ["unlisted", "private"],
    do: []

  defp get_reply_tasks("direct", "user"), do: ~w(friend user friend)
  defp get_reply_tasks("direct", "friends"), do: ~w(user friend user)
  defp get_reply_tasks("direct", "non_friends"), do: ~w(user non_friend user)

  defp insert_replies(tasks, visibility, user, friends, non_friends, acc) do
    Enum.reduce(tasks, acc, fn
      "friend", {id, data} ->
        friend = Enum.random(friends)
        insert_reply(friend, data, id, visibility)

      "non_friend", {id, data} ->
        non_friend = Enum.random(non_friends)
        insert_reply(non_friend, data, id, visibility)

      "user", {id, data} ->
        insert_reply(user, data, id, visibility)
    end)
  end

  defp insert_direct_replies(tasks, user, list, acc) do
    Enum.reduce(tasks, acc, fn
      group, {id, data} when group in ["friend", "non_friend"] ->
        actor = Enum.random(list)

        {reply_id, _} =
          insert_reply(actor, List.delete(data, "@" <> actor.nickname), id, "direct")

        {reply_id, data}

      "user", {id, data} ->
        {reply_id, _} = insert_reply(user, List.delete(data, "@" <> user.nickname), id, "direct")
        {reply_id, data}
    end)
  end

  defp insert_reply(actor, data, activity_id, visibility) do
    {:ok, reply} =
      CommonAPI.post(actor, %{
        "status" => Enum.join(data, ", "),
        "visibility" => visibility,
        "in_reply_to_status_id" => activity_id
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
