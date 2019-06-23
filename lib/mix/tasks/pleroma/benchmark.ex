defmodule Mix.Tasks.Pleroma.Benchmark do
  import Mix.Pleroma
  use Mix.Task

  def run(["search"]) do
    start_pleroma()

    Benchee.run(%{
      "search" => fn ->
        Pleroma.Activity.search(nil, "cofe")
      end
    })
  end

  def run(["tag"]) do
    start_pleroma()

    Benchee.run(%{
      "tag" => fn ->
        %{"type" => "Create", "tag" => "cofe"}
        |> Pleroma.Web.ActivityPub.ActivityPub.fetch_public_activities()
      end
    })
  end
end
