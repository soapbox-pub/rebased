defmodule Pleroma.Workers.SearchIndexingWorker do
  use Pleroma.Workers.WorkerHelper, queue: "search_indexing"

  @impl Oban.Worker

  def perform(%Job{args: %{"op" => "add_to_index", "activity" => activity_id}}) do
    activity = Pleroma.Activity.get_by_id_with_object(activity_id)

    search_module = Pleroma.Config.get([Pleroma.Search, :module])

    search_module.add_to_index(activity)
  end

  def perform(%Job{args: %{"op" => "remove_from_index", "object" => object_id}}) do
    object = Pleroma.Object.get_by_id(object_id)

    search_module = Pleroma.Config.get([Pleroma.Search, :module])

    search_module.remove_from_index(object)
  end
end
