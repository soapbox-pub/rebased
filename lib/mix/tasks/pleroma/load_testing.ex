defmodule Mix.Tasks.Pleroma.LoadTesting do
  use Mix.Task
  use Pleroma.LoadTesting.Helper
  import Mix.Pleroma
  import Pleroma.LoadTesting.Generator
  import Pleroma.LoadTesting.Fetcher

  # tODO: remove autovacuum worker until generation is not ended
  @shortdoc "Factory for generation data"
  @moduledoc """
  Generates data like:
  - users
  - activities with notifications

  ## Generate data
      MIX_ENV=test mix pleroma.load_testing --users 10000 --activities 20000
      MIX_ENV=test mix pleroma.load_testing -u 10000 -a 20000

  Options:
  - `--users NUMBER` - number of users to generate (default: 10000)
  - `--activities NUMBER` - number of activities to generate (default: 20000)
  """

  @aliases [u: :users, a: :activities]
  @switches [
    users: :integer,
    activities: :integer,
    dms: :integer,
    thread_length: :integer,
    non_visible_posts: :integer
  ]
  @users_default 20_000
  @activities_default 50_000
  @dms_default 50_000
  @thread_length_default 2_000
  @non_visible_posts_default 2_000

  def run(args) do
    start_pleroma()
    {opts, _} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    users_max = Keyword.get(opts, :users, @users_default)
    activities_max = Keyword.get(opts, :activities, @activities_default)
    dms_max = Keyword.get(opts, :dms, @dms_default)
    long_thread_length = Keyword.get(opts, :thread_length, @thread_length_default)
    non_visible_posts = Keyword.get(opts, :non_visible_posts, @non_visible_posts_default)

    clean_tables()

    opts =
      Keyword.put(opts, :users_max, users_max)
      |> Keyword.put(:activities_max, activities_max)
      |> Keyword.put(:dms_max, dms_max)
      |> Keyword.put(:long_thread_length, long_thread_length)
      |> Keyword.put(:non_visible_posts_max, non_visible_posts)

    generate_users(opts)

    # main user for queries
    IO.puts("Fetching main user...")

    {time, user} =
      :timer.tc(fn -> Repo.one(from(u in User, order_by: fragment("RANDOM()"), limit: 1)) end)

    IO.puts("Fetching main user take #{to_sec(time)} sec.\n")

    IO.puts("Fetching users...")

    {time, users} =
      :timer.tc(fn ->
        Repo.all(
          from(u in User,
            where: u.id != ^user.id,
            order_by: fragment("RANDOM()"),
            limit: 10
          )
        )
      end)

    IO.puts("Fetching users take #{to_sec(time)} sec.\n")

    generate_activities(users, opts)

    generate_activities(users, Keyword.put(opts, :mention, user))

    generate_dms(user, users, opts)

    {:ok, activity} = generate_long_thread(user, users, opts)

    generate_private_thread(users, opts)

    # generate_replies(user, users, activities)

    # activity = Enum.random(activities)
    # generate_long_thread(user, users, activity)

    IO.puts("Users in DB: #{Repo.aggregate(from(u in User), :count, :id)}")
    IO.puts("Activities in DB: #{Repo.aggregate(from(a in Activity), :count, :id)}")
    IO.puts("Objects in DB: #{Repo.aggregate(from(o in Object), :count, :id)}")
    IO.puts("Notifications in DB: #{Repo.aggregate(from(n in Notification), :count, :id)}")

    fetch_user(user)
    query_timelines(user)
    query_notifications(user)
    query_dms(user)
    query_long_thread(user, activity)
    query_timelines(user)
  end

  defp clean_tables do
    IO.puts("\n\nDeleting old data...\n")
    Ecto.Adapters.SQL.query!(Repo, "TRUNCATE users CASCADE;")
    Ecto.Adapters.SQL.query!(Repo, "TRUNCATE activities CASCADE;")
    Ecto.Adapters.SQL.query!(Repo, "TRUNCATE objects CASCADE;")
  end
end
