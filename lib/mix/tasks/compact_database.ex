defmodule Mix.Tasks.CompactDatabase do
  @moduledoc """
  Compact the database by flattening the object graph.
  """

  require Logger

  use Mix.Task
  import Mix.Ecto
  import Ecto.Query
  alias Pleroma.{Repo, Object, Activity}

  defp maybe_compact(%Activity{data: %{"object" => %{"id" => object_id}}} = activity) do
    data =
      activity.data
      |> Map.put("object", object_id)

    {:ok, activity} =
      Activity.change(activity, %{data: data})
      |> Repo.update()

    {:ok, activity}
  end

  defp maybe_compact(%Activity{} = activity), do: {:ok, activity}

  defp activity_query(min_id, max_id) do
    from(
      a in Activity,
      where: fragment("?->>'type' = 'Create'", a.data),
      where: a.id >= ^min_id,
      where: a.id < ^max_id
    )
  end

  def run(args) do
    Application.ensure_all_started(:pleroma)

    max = Repo.aggregate(Activity, :max, :id)
    Logger.info("Considering #{max} activities")

    chunks = 0..round(max / 100)

    Enum.each(chunks, fn i ->
      min = i * 100
      max = min + 100

      activity_query(min, max)
      |> Repo.all()
      |> Enum.each(&maybe_compact/1)

      IO.write(".")
    end)

    Logger.info("Finished.")
  end
end
