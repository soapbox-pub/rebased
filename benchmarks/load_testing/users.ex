defmodule Pleroma.LoadTesting.Users do
  @moduledoc """
  Module for generating users with friends.
  """
  import Ecto.Query
  import Pleroma.LoadTesting.Helper, only: [to_sec: 1]

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.User.Query

  @defaults [
    users: 20_000,
    friends: 100
  ]

  @max_concurrency 10

  @spec generate(keyword()) :: User.t()
  def generate(opts \\ []) do
    opts = Keyword.merge(@defaults, opts)

    generate_users(opts[:users])

    main_user =
      Repo.one(from(u in User, where: u.local == true, order_by: fragment("RANDOM()"), limit: 1))

    make_friends(main_user, opts[:friends])

    Repo.get(User, main_user.id)
  end

  def generate_users(max) do
    IO.puts("Starting generating #{max} users...")

    {time, _} =
      :timer.tc(fn ->
        Task.async_stream(
          1..max,
          &generate_user(&1),
          max_concurrency: @max_concurrency,
          timeout: 30_000
        )
        |> Stream.run()
      end)

    IO.puts("Generating users take #{to_sec(time)} sec.\n")
  end

  defp generate_user(i) do
    remote = Enum.random([true, false])

    %User{
      name: "Test テスト User #{i}",
      email: "user#{i}@example.com",
      nickname: "nick#{i}",
      password_hash: Comeonin.Pbkdf2.hashpwsalt("test"),
      bio: "Tester Number #{i}",
      local: !remote
    }
    |> user_urls()
    |> Repo.insert!()
  end

  defp user_urls(%{local: true} = user) do
    urls = %{
      ap_id: User.ap_id(user),
      follower_address: User.ap_followers(user),
      following_address: User.ap_following(user)
    }

    Map.merge(user, urls)
  end

  defp user_urls(%{local: false} = user) do
    base_domain = Enum.random(["domain1.com", "domain2.com", "domain3.com"])

    ap_id = "https://#{base_domain}/users/#{user.nickname}"

    urls = %{
      ap_id: ap_id,
      follower_address: ap_id <> "/followers",
      following_address: ap_id <> "/following"
    }

    Map.merge(user, urls)
  end

  def make_friends(main_user, max) when is_integer(max) do
    IO.puts("Starting making friends for #{max} users...")

    {time, _} =
      :timer.tc(fn ->
        number_of_users =
          (max / 2)
          |> Kernel.trunc()

        main_user
        |> get_users(%{limit: number_of_users, local: :local})
        |> run_stream(main_user)

        main_user
        |> get_users(%{limit: number_of_users, local: :external})
        |> run_stream(main_user)
      end)

    IO.puts("Making friends take #{to_sec(time)} sec.\n")
  end

  def make_friends(%User{} = main_user, %User{} = user) do
    {:ok, _} = User.follow(main_user, user)
    {:ok, _} = User.follow(user, main_user)
  end

  @spec get_users(User.t(), keyword()) :: [User.t()]
  def get_users(user, opts) do
    criteria = %{limit: opts[:limit]}

    criteria =
      if opts[:local] do
        Map.put(criteria, opts[:local], true)
      else
        criteria
      end

    criteria =
      if opts[:friends?] do
        Map.put(criteria, :friends, user)
      else
        criteria
      end

    query =
      criteria
      |> Query.build()
      |> random_without_user(user)

    query =
      if opts[:friends?] == false do
        friends_ids =
          %{friends: user}
          |> Query.build()
          |> Repo.all()
          |> Enum.map(& &1.id)

        from(u in query, where: u.id not in ^friends_ids)
      else
        query
      end

    Repo.all(query)
  end

  defp random_without_user(query, user) do
    from(u in query,
      where: u.id != ^user.id,
      order_by: fragment("RANDOM()")
    )
  end

  defp run_stream(users, main_user) do
    Task.async_stream(users, &make_friends(main_user, &1),
      max_concurrency: @max_concurrency,
      timeout: 30_000
    )
    |> Stream.run()
  end
end
