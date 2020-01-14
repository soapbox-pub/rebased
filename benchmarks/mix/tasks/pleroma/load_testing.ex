defmodule Mix.Tasks.Pleroma.LoadTesting do
  use Mix.Task
  import Ecto.Query

  alias Ecto.Adapters.SQL
  alias Pleroma.Repo
  alias Pleroma.User

  @shortdoc "Factory for generation data"
  @moduledoc """
  Generates data like:
  - local/remote users
  - local/remote activities with differrent visibility:
    - simple activiities
    - with emoji
    - with mentions
    - hellthreads
    - with attachments
    - with tags
    - likes
    - reblogs
    - simple threads
    - long threads

  ## Generate data
      MIX_ENV=benchmark mix pleroma.load_testing --users 20000 --friends 1000 --iterations 170 --friends_used 20 --non_friends_used 20
      MIX_ENV=benchmark mix pleroma.load_testing -u 20000 -f 1000 -i 170 -fu 20 -nfu 20

  Options:
  - `--users NUMBER` - number of users to generate. Defaults to: 20000. Alias: `-u`
  - `--friends NUMBER` - number of friends for main user. Defaults to: 1000. Alias: `-f`
  - `--iterations NUMBER` - number of iterations to generate activities. For each iteration in database is inserted about 120+ activities with different visibility, actors and types.Defaults to: 170. Alias: `-i`
  - `--friends_used NUMBER` - number of main user friends used in activity generation. Defaults to: 20. Alias: `-fu`
  - `--non_friends_used NUMBER` - number of non friends used in activity generation. Defaults to: 20. Alias: `-nfu`
  """

  @aliases [u: :users, f: :friends, i: :iterations, fu: :friends_used, nfu: :non_friends_used]
  @switches [
    users: :integer,
    friends: :integer,
    iterations: :integer,
    friends_used: :integer,
    non_friends_used: :integer
  ]

  def run(args) do
    Mix.Pleroma.start_pleroma()
    clean_tables()
    {opts, _} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    user = Pleroma.LoadTesting.Users.generate(opts)
    Pleroma.LoadTesting.Activities.generate(user, opts)

    IO.puts("Users in DB: #{Repo.aggregate(from(u in User), :count, :id)}")

    IO.puts("Activities in DB: #{Repo.aggregate(from(a in Pleroma.Activity), :count, :id)}")

    IO.puts("Objects in DB: #{Repo.aggregate(from(o in Pleroma.Object), :count, :id)}")

    IO.puts(
      "Notifications in DB: #{Repo.aggregate(from(n in Pleroma.Notification), :count, :id)}"
    )

    Pleroma.LoadTesting.Fetcher.run_benchmarks(user)
  end

  defp clean_tables do
    IO.puts("Deleting old data...\n")
    SQL.query!(Repo, "TRUNCATE users CASCADE;")
    SQL.query!(Repo, "TRUNCATE activities CASCADE;")
    SQL.query!(Repo, "TRUNCATE objects CASCADE;")
    SQL.query!(Repo, "TRUNCATE oban_jobs CASCADE;")
  end
end
