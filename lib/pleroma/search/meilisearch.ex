defmodule Pleroma.Search.Meilisearch do
  require Logger
  require Pleroma.Constants

  alias Pleroma.Activity

  import Pleroma.Activity.Search
  import Ecto.Query

  defp meili_headers() do
    private_key = Pleroma.Config.get([Pleroma.Search.Meilisearch, :private_key])

    [{"Content-Type", "application/json"}] ++
      if is_nil(private_key), do: [], else: [{"X-Meili-API-Key", private_key}]
  end

  def meili_get!(path) do
    endpoint = Pleroma.Config.get([Pleroma.Search.Meilisearch, :url])

    {:ok, result} =
      Pleroma.HTTP.get(
        Path.join(endpoint, path),
        meili_headers()
      )

    Jason.decode!(result.body)
  end

  def meili_post!(path, params) do
    endpoint = Pleroma.Config.get([Pleroma.Search.Meilisearch, :url])

    {:ok, result} =
      Pleroma.HTTP.post(
        Path.join(endpoint, path),
        Jason.encode!(params),
        meili_headers()
      )

    Jason.decode!(result.body)
  end

  def meili_delete!(path) do
    endpoint = Pleroma.Config.get([Pleroma.Search.Meilisearch, :url])

    {:ok, _} =
      Pleroma.HTTP.request(
        :delete,
        Path.join(endpoint, path),
        "",
        meili_headers(),
        []
      )
  end

  def search(user, query, options \\ []) do
    limit = Enum.min([Keyword.get(options, :limit), 40])
    offset = Keyword.get(options, :offset, 0)
    author = Keyword.get(options, :author)

    result =
      meili_post!(
        "/indexes/objects/search",
        %{q: query, offset: offset, limit: limit}
      )

    hits = result["hits"] |> Enum.map(& &1["ap"])

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
      |> order_by([object: obj], desc: obj.data["published"])
      |> Pleroma.Repo.all()
    rescue
      _ -> maybe_fetch([], user, query)
    end
  end

  def object_to_search_data(object) do
    if not is_nil(object) and object.data["type"] == "Note" and
         Pleroma.Constants.as_public() in object.data["to"] do
      data = object.data

      content_str =
        case data["content"] do
          [nil | rest] -> to_string(rest)
          str -> str
        end

      content =
        with {:ok, scrubbed} <- FastSanitize.strip_tags(content_str),
             trimmed <- String.trim(scrubbed) do
          trimmed
        end

      if String.length(content) > 1 do
        {:ok, published, _} = DateTime.from_iso8601(data["published"])

        %{
          id: object.id,
          content: content,
          ap: data["id"],
          published: published |> DateTime.to_unix()
        }
      end
    end
  end

  def add_to_index(activity) do
    maybe_search_data = object_to_search_data(activity.object)

    if activity.data["type"] == "Create" and maybe_search_data do
      result =
        meili_post!(
          "/indexes/objects/documents",
          [maybe_search_data]
        )

      if not Map.has_key?(result, "updateId") do
        Logger.error("Failed to add activity #{activity.id} to index: #{inspect(result)}")
      end
    end
  end

  def remove_from_index(object) do
    meili_delete!("/indexes/objects/documents/#{object.id}")
  end
end
