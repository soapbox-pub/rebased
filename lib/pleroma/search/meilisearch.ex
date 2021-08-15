defmodule Pleroma.Search.Meilisearch do
  require Logger

  alias Pleroma.Activity

  import Pleroma.Activity.Search
  import Ecto.Query

  def search(user, query, options \\ []) do
    limit = Enum.min([Keyword.get(options, :limit), 40])
    offset = Keyword.get(options, :offset, 0)
    author = Keyword.get(options, :author)

    endpoint = Pleroma.Config.get([Pleroma.Search.Meilisearch, :url])

    {:ok, result} =
      Pleroma.HTTP.post(
        "#{endpoint}/indexes/objects/search",
        Jason.encode!(%{q: query, offset: offset, limit: limit})
      )

    hits = Jason.decode!(result.body)["hits"] |> Enum.map(& &1["ap"])

    try do
      hits
      |> Activity.create_by_object_ap_id()
      |> Activity.with_preloaded_object()
      |> Activity.with_preloaded_object()
      |> Activity.restrict_deactivated_users()
      |> maybe_restrict_local(user)
      |> maybe_restrict_author(author)
      |> maybe_restrict_blocked(user)
      |> maybe_fetch(user, query)
      |> order_by([activity], desc: activity.id)
      |> Pleroma.Repo.all()
    rescue
      _ -> maybe_fetch([], user, query)
    end
  end

  def add_to_index(activity) do
    object = activity.object

    if activity.data["type"] == "Create" and not is_nil(object) and object.data["type"] == "Note" do
      data = object.data

      endpoint = Pleroma.Config.get([Pleroma.Search.Meilisearch, :url])

      {:ok, result} =
        Pleroma.HTTP.post(
          "#{endpoint}/indexes/objects/documents",
          Jason.encode!([%{id: object.id, source: data["source"], ap: data["id"]}])
        )

      if not Map.has_key?(Jason.decode!(result.body), "updateId") do
        Logger.error("Failed to add activity #{activity.id} to index: #{result.body}")
      end
    end
  end
end
