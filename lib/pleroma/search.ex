defmodule Pleroma.Search do
  alias Pleroma.Workers.SearchIndexingWorker

  def add_to_index(%Pleroma.Activity{id: activity_id}) do
    SearchIndexingWorker.new(%{"op" => "add_to_index", "activity" => activity_id})
    |> Oban.insert()
  end

  def remove_from_index(%Pleroma.Object{id: object_id}) do
    SearchIndexingWorker.new(%{"op" => "remove_from_index", "object" => object_id})
    |> Oban.insert()
  end

  def search(query, options) do
    search_module = Pleroma.Config.get([Pleroma.Search, :module])
    search_module.search(options[:for_user], query, options)
  end

  def healthcheck_endpoints do
    search_module = Pleroma.Config.get([Pleroma.Search, :module])
    search_module.healthcheck_endpoints()
  end
end
