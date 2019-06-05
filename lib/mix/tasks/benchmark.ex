defmodule Mix.Tasks.Pleroma.Benchmark do
  use Mix.Task
  alias Mix.Tasks.Pleroma.Common

  def run(["search"]) do
    Common.start_pleroma()

    Benchee.run(%{
      "search" => fn ->
        Pleroma.Activity.search(nil, "cofe")
      end
    })
  end

  def run(["tag"]) do
    Common.start_pleroma()

    Benchee.run(%{
      "tag" => fn ->
        %{"type" => "Create", "tag" => "cofe"}
        |> Pleroma.Web.ActivityPub.ActivityPub.fetch_public_activities()
      end
    })
  end
end
