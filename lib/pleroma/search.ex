defmodule Pleroma.Search do
  alias Pleroma.Workers.SearchIndexingWorker

  def add_to_index(activity) do
    SearchIndexingWorker.enqueue("add_to_index", %{"activity" => activity.id})
  end

  def remove_from_index(object) do
    SearchIndexingWorker.enqueue("remove_from_index", %{"object" => object.id})
  end

  def search(query, options) do
    search_module = Pleroma.Config.get([Pleroma.Search, :module], Pleroma.Activity)

    search_module.search(options[:for_user], query, options)
  end
end
