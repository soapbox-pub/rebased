defmodule Pleroma.LoadTesting.Generator do
  use Pleroma.LoadTesting.Helper

  def generate_users(opts) do
    IO.puts("Starting generating #{opts[:users_max]} users...")
    {time, _} = :timer.tc(fn -> do_generate_users(opts) end)
    IO.puts("Inserting users take #{to_sec(time)} sec.\n")
  end

  defp do_generate_users(opts) do
    max = Keyword.get(opts, :users_max)

    Task.async_stream(
      1..max,
      &generate_user_data(&1),
      max_concurrency: 10,
      timeout: 30_000
    )
    |> Enum.to_list()
  end

  defp generate_user_data(i) do
    user = %User{
      name: "Test テスト User #{i}",
      email: "user#{i}@example.com",
      nickname: "nick#{i}",
      password_hash: Comeonin.Pbkdf2.hashpwsalt("test"),
      bio: "Tester Number #{i}",
      info: %{}
    }

    user = %{
      user
      | ap_id: User.ap_id(user),
        follower_address: User.ap_followers(user),
        following_address: User.ap_following(user),
        following: [User.ap_id(user)]
    }

    Pleroma.Repo.insert!(user)
  end

  def generate_activities(users, opts) do
    IO.puts("Starting generating #{opts[:activities_max]} activities...")
    {time, _} = :timer.tc(fn -> do_generate_activities(users, opts) end)
    IO.puts("Inserting activities take #{to_sec(time)} sec.\n")
  end

  defp do_generate_activities(users, opts) do
    Task.async_stream(
      1..opts[:activities_max],
      fn _ ->
        do_generate_activity(users, opts)
      end,
      max_concurrency: 10,
      timeout: 30_000
    )
    |> Stream.run()
  end

  defp do_generate_activity(users, opts) do
    status =
      if opts[:mention],
        do: "some status with @#{opts[:mention].nickname}",
        else: "some status"

    Pleroma.Web.CommonAPI.post(Enum.random(users), %{"status" => status})
  end

  def generate_dms(user, users, opts) do
    IO.puts("Starting generating #{opts[:dms_max]} DMs")
    {time, _} = :timer.tc(fn -> do_generate_dms(user, users, opts) end)
    IO.puts("Inserting dms take #{to_sec(time)} sec.\n")
  end

  defp do_generate_dms(user, users, opts) do
    Task.async_stream(
      1..opts[:dms_max],
      fn _ ->
        do_generate_dm(user, users)
      end,
      max_concurrency: 10,
      timeout: 30_000
    )
    |> Stream.run()
  end

  defp do_generate_dm(user, users) do
    post = %{
      "status" => "@#{user.nickname} some direct message",
      "visibility" => "direct"
    }

    Pleroma.Web.CommonAPI.post(Enum.random(users), post)
  end

  def generate_long_thread(user, users, opts) do
    IO.puts("Starting generating long thread with #{opts[:long_thread_length]} replies")
    {time, activity} = :timer.tc(fn -> do_generate_long_thread(user, users, opts) end)
    IO.puts("Inserting long thread replies take #{to_sec(time)} sec.\n")
    {:ok, activity}
  end

  defp do_generate_long_thread(user, users, opts) do
    {:ok, %{id: id} = activity} =
      Pleroma.Web.CommonAPI.post(user, %{"status" => "Start of long thread"})

    Task.async_stream(
      1..opts[:long_thread_length],
      fn _ -> do_generate_thread(users, id) end,
      max_concurrency: 10,
      timeout: 30_000
    )
    |> Stream.run()

    activity
  end

  defp do_generate_thread(users, activity_id) do
    Pleroma.Web.CommonAPI.post(Enum.random(users), %{
      "status" => "reply to main post",
      "in_reply_to_status_id" => activity_id
    })
  end

  def generate_private_thread(users, opts) do
    IO.puts("Starting generating long thread with #{opts[:non_visible_posts_max]} replies")
    {time, _} = :timer.tc(fn -> do_generate_non_visible_posts(users, opts) end)
    IO.puts("Inserting long thread replies take #{to_sec(time)} sec.\n")
  end

  defp do_generate_non_visible_posts(users, opts) do
    [user1, user2] = Enum.take(users, 2)
    {:ok, user1} = Pleroma.User.follow(user1, user2)
    {:ok, user2} = Pleroma.User.follow(user2, user1)

    {:ok, activity} =
      Pleroma.Web.CommonAPI.post(user1, %{
        "status" => "Some private post",
        "visibility" => "private"
      })

    {:ok, activity_public} =
      Pleroma.Web.CommonAPI.post(user2, %{
        "status" => "Some public reply",
        "in_reply_to_status_id" => activity.id
      })

    Task.async_stream(
      1..opts[:non_visible_posts_max],
      fn _ -> do_generate_non_visible_post(users, activity_public) end,
      max_concurrency: 10,
      timeout: 30_000
    )
  end

  defp do_generate_non_visible_post(users, activity) do
    visibility = Enum.random(["private", "public"])

    Pleroma.Web.CommonAPI.post(Enum.random(users), %{
      "visibility" => visibility,
      "status" => "Some #{visibility} reply",
      "in_reply_to_status_id" => activity.id
    })
  end
end
