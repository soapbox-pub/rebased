defmodule Pleroma.Search do
  alias Pleroma.Workers.SearchIndexingWorker

  def add_to_index(%Pleroma.Activity{id: activity_id}) do
    SearchIndexingWorker.enqueue("add_to_index", %{"activity" => activity_id})
  end

  def remove_from_index(%Pleroma.Object{id: object_id}) do
    SearchIndexingWorker.enqueue("remove_from_index", %{"object" => object_id})
  end

  def search(query, options) do
    search_module = Pleroma.Config.get([Pleroma.Search, :module], Pleroma.Activity)

    search_module.search(options[:for_user], query, options)
  end
end
