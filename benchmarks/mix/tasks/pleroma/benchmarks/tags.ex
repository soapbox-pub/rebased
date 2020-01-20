defmodule Mix.Tasks.Pleroma.Benchmarks.Tags do
  use Mix.Task
  alias Pleroma.Repo
  alias Pleroma.LoadTesting.Generator
  import Ecto.Query

  def run(_args) do
    Mix.Pleroma.start_pleroma()
    activities_count = Repo.aggregate(from(a in Pleroma.Activity), :count, :id)

    if activities_count == 0 do
      IO.puts("Did not find any activities, cleaning and generating")
      clean_tables()
      Generator.generate_users(users_max: 10)
      Generator.generate_tagged_activities()
    else
      IO.puts("Found #{activities_count} activities, won't generate new ones")
    end

    tags = Enum.map(0..20, fn i -> {"For #tag_#{i}", "tag_#{i}"} end)

    Enum.each(tags, fn {_, tag} ->
      query =
        from(o in Pleroma.Object,
          where: fragment("(?)->'tag' \\? (?)", o.data, ^tag)
        )

      count = Repo.aggregate(query, :count, :id)
      IO.puts("Database contains #{count} posts tagged with #{tag}")
    end)

    user = Repo.all(Pleroma.User) |> List.first()

    Benchee.run(
      %{
        "Hashtag fetching, any" => fn tags ->
          Pleroma.Web.MastodonAPI.TimelineController.hashtag_fetching(
            %{
              "any" => tags
            },
            user,
            false
          )
        end,
        # Will always return zero results because no overlapping hashtags are generated.
        "Hashtag fetching, all" => fn tags ->
          Pleroma.Web.MastodonAPI.TimelineController.hashtag_fetching(
            %{
              "all" => tags
            },
            user,
            false
          )
        end
      },
      inputs:
        tags
        |> Enum.map(fn {_, v} -> v end)
        |> Enum.chunk_every(2)
        |> Enum.map(fn tags -> {"For #{inspect(tags)}", tags} end),
      time: 5
    )

    Benchee.run(
      %{
        "Hashtag fetching" => fn tag ->
          Pleroma.Web.MastodonAPI.TimelineController.hashtag_fetching(
            %{
              "tag" => tag
            },
            user,
            false
          )
        end
      },
      inputs: tags,
      time: 5
    )
  end

  defp clean_tables do
    IO.puts("Deleting old data...\n")
    Ecto.Adapters.SQL.query!(Repo, "TRUNCATE users CASCADE;")
    Ecto.Adapters.SQL.query!(Repo, "TRUNCATE activities CASCADE;")
    Ecto.Adapters.SQL.query!(Repo, "TRUNCATE objects CASCADE;")
  end
end
