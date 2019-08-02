defmodule Pleroma.LoadTesting.Generator do
  use Pleroma.LoadTesting.Helper

  def generate_users(opts) do
    IO.puts("Starting generating #{opts[:users_max]} users...")
    {time, _} = :timer.tc(fn -> do_generate_users(opts) end)
    IO.puts("Inserting users take #{to_sec(time)} sec.\n")
  end

  defp do_generate_users(opts) do
    min = Keyword.get(opts, :users_min, 1)
    max = Keyword.get(opts, :users_max)

    query =
      "INSERT INTO \"users\" (\"ap_id\",\"bio\",\"email\",\"follower_address\",\"following\",\"following_address\",\"info\",
      \"local\",\"name\",\"nickname\",\"password_hash\",\"tags\",\"id\",\"inserted_at\",\"updated_at\") VALUES \n"

    users =
      Task.async_stream(
        min..max,
        &generate_user_data(&1),
        max_concurrency: 10,
        timeout: 30_000
      )
      |> Enum.reduce("", fn {:ok, data}, acc -> acc <> data <> ", \n" end)

    query = query <> String.replace_trailing(users, ", \n", ";")

    Ecto.Adapters.SQL.query!(Repo, query)
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

    "('#{user.ap_id}', '#{user.bio}', '#{user.email}', '#{user.follower_address}', '{#{
      user.following
    }}', '#{user.following_address}', '#{Jason.encode!(user.info)}', '#{user.local}', '#{
      user.name
    }', '#{user.nickname}', '#{user.password_hash}', '{#{user.tags}}', uuid_generate_v4(), NOW(), NOW())"
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
end
