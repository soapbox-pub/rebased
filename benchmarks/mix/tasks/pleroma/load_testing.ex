defmodule Mix.Tasks.Pleroma.LoadTesting do
  use Mix.Task
  use Pleroma.LoadTesting.Helper
  import Mix.Pleroma
  import Pleroma.LoadTesting.Generator
  import Pleroma.LoadTesting.Fetcher

  @shortdoc "Factory for generation data"
  @moduledoc """
  Generates data like:
  - local/remote users
  - local/remote activities with notifications
  - direct messages
  - long thread
  - non visible posts

  ## Generate data
      MIX_ENV=benchmark mix pleroma.load_testing --users 20000 --dms 20000 --thread_length 2000
      MIX_ENV=benchmark mix pleroma.load_testing -u 20000 -d 20000 -t 2000

  Options:
  - `--users NUMBER` - number of users to generate. Defaults to: 20000. Alias: `-u`
  - `--dms NUMBER` - number of direct messages to generate. Defaults to: 20000. Alias `-d`
  - `--thread_length` - number of messages in thread. Defaults to: 2000. ALias `-t`
  """

  @aliases [u: :users, d: :dms, t: :thread_length]
  @switches [
    users: :integer,
    dms: :integer,
    thread_length: :integer
  ]
  @users_default 20_000
  @dms_default 1_000
  @thread_length_default 2_000

  def run(args) do
    start_pleroma()
    Pleroma.Config.put([:instance, :skip_thread_containment], true)
    {opts, _} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    users_max = Keyword.get(opts, :users, @users_default)
    dms_max = Keyword.get(opts, :dms, @dms_default)
    thread_length = Keyword.get(opts, :thread_length, @thread_length_default)

    clean_tables()

    opts =
      Keyword.put(opts, :users_max, users_max)
      |> Keyword.put(:dms_max, dms_max)
      |> Keyword.put(:thread_length, thread_length)

    generate_users(opts)

    # main user for queries
    IO.puts("Fetching local main user...")

    {time, user} =
      :timer.tc(fn ->
        Repo.one(
          from(u in User, where: u.local == true, order_by: fragment("RANDOM()"), limit: 1)
        )
      end)

    IO.puts("Fetching main user take #{to_sec(time)} sec.\n")

    IO.puts("Fetching local users...")

    {time, users} =
      :timer.tc(fn ->
        Repo.all(
          from(u in User,
            where: u.id != ^user.id,
            where: u.local == true,
            order_by: fragment("RANDOM()"),
            limit: 10
          )
        )
      end)

    IO.puts("Fetching local users take #{to_sec(time)} sec.\n")

    IO.puts("Fetching remote users...")

    {time, remote_users} =
      :timer.tc(fn ->
        Repo.all(
          from(u in User,
            where: u.id != ^user.id,
            where: u.local == false,
            order_by: fragment("RANDOM()"),
            limit: 10
          )
        )
      end)

    IO.puts("Fetching remote users take #{to_sec(time)} sec.\n")

    generate_activities(user, users)

    generate_remote_activities(user, remote_users)

    generate_like_activities(
      user, Pleroma.Repo.all(Pleroma.Activity.Queries.by_type("Create"))
    )

    generate_dms(user, users, opts)

    {:ok, activity} = generate_long_thread(user, users, opts)

    generate_non_visible_message(user, users)

    IO.puts("Users in DB: #{Repo.aggregate(from(u in User), :count, :id)}")

    IO.puts("Activities in DB: #{Repo.aggregate(from(a in Pleroma.Activity), :count, :id)}")

    IO.puts("Objects in DB: #{Repo.aggregate(from(o in Pleroma.Object), :count, :id)}")

    IO.puts(
      "Notifications in DB: #{Repo.aggregate(from(n in Pleroma.Notification), :count, :id)}"
    )

    fetch_user(user)
    query_timelines(user)
    query_notifications(user)
    query_dms(user)
    query_long_thread(user, activity)
    Pleroma.Config.put([:instance, :skip_thread_containment], false)
    query_timelines(user)
  end

  defp clean_tables do
    IO.puts("Deleting old data...\n")
    Ecto.Adapters.SQL.query!(Repo, "TRUNCATE users CASCADE;")
    Ecto.Adapters.SQL.query!(Repo, "TRUNCATE activities CASCADE;")
    Ecto.Adapters.SQL.query!(Repo, "TRUNCATE objects CASCADE;")
  end
end
