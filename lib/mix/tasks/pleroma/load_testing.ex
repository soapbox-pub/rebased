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

  @aliases [u: :users, a: :activities, d: :delete]
  @switches [users: :integer, activities: :integer, delete: :boolean]
  @users_default 20_000
  @activities_default 50_000

  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)
    start_pleroma()

    current_max = Keyword.get(opts, :users, @users_default)
    activities_max = Keyword.get(opts, :activities, @activities_default)

    {users_min, users_max} =
      if opts[:delete] do
        clean_tables()
        {1, current_max}
      else
        current_count = Repo.aggregate(from(u in User), :count, :id) + 1
        {current_count, current_max + current_count}
      end

    opts =
      Keyword.put(opts, :users_min, users_min)
      |> Keyword.put(:users_max, users_max)
      |> Keyword.put(:activities_max, activities_max)

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

    # generate_replies(user, users, activities)

    # activity = Enum.random(activities)
    # generate_long_thread(user, users, activity)

    IO.puts("Users in DB: #{Repo.aggregate(from(u in User), :count, :id)}")
    IO.puts("Activities in DB: #{Repo.aggregate(from(a in Activity), :count, :id)}")
    IO.puts("Objects in DB: #{Repo.aggregate(from(o in Object), :count, :id)}")
    IO.puts("Notifications in DB: #{Repo.aggregate(from(n in Notification), :count, :id)}")

    query_timelines(user)
    query_notifications(user)
    # query_long_thread(user, activity)
  end

  defp clean_tables do
    IO.puts("\n\nDeleting old data...\n")
    Ecto.Adapters.SQL.query!(Repo, "TRUNCATE users CASCADE;")
    Ecto.Adapters.SQL.query!(Repo, "TRUNCATE activities CASCADE;")
    Ecto.Adapters.SQL.query!(Repo, "TRUNCATE objects CASCADE;")
  end
end
