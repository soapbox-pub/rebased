defmodule Pleroma.Search.QdrantSearch do
  @behaviour Pleroma.Search.SearchBackend
  import Ecto.Query

  alias Pleroma.Activity
  alias Pleroma.Config.Getting, as: Config

  alias __MODULE__.OpenAIClient
  alias __MODULE__.QdrantClient

  import Pleroma.Search.Meilisearch, only: [object_to_search_data: 1]
  import Pleroma.Search.DatabaseSearch, only: [maybe_fetch: 3]

  @impl true
  def create_index do
    payload = Config.get([Pleroma.Search.QdrantSearch, :qdrant_index_configuration])

    with {:ok, %{status: 200}} <- QdrantClient.put("/collections/posts", payload) do
      :ok
    else
      e -> {:error, e}
    end
  end

  @impl true
  def drop_index do
    with {:ok, %{status: 200}} <- QdrantClient.delete("/collections/posts") do
      :ok
    else
      e -> {:error, e}
    end
  end

  def get_embedding(text) do
    with {:ok, %{body: %{"data" => [%{"embedding" => embedding}]}}} <-
           OpenAIClient.post("/v1/embeddings", %{
             input: text,
             model: Config.get([Pleroma.Search.QdrantSearch, :openai_model])
           }) do
      {:ok, embedding}
    else
      _ ->
        {:error, "Failed to get embedding"}
    end
  end

  defp actor_from_activity(%{data: %{"actor" => actor}}) do
    actor
  end

  defp actor_from_activity(_), do: nil

  defp build_index_payload(activity, embedding) do
    actor = actor_from_activity(activity)
    published_at = activity.data["published"]

    %{
      points: [
        %{
          id: activity.id |> FlakeId.from_string() |> Ecto.UUID.cast!(),
          vector: embedding,
          payload: %{actor: actor, published_at: published_at}
        }
      ]
    }
  end

  defp build_search_payload(embedding, options) do
    base = %{
      vector: embedding,
      limit: options[:limit] || 20,
      offset: options[:offset] || 0
    }

    if author = options[:author] do
      Map.put(base, :filter, %{
        must: [%{key: "actor", match: %{value: author.ap_id}}]
      })
    else
      base
    end
  end

  @impl true
  def add_to_index(activity) do
    # This will only index public or unlisted notes
    maybe_search_data = object_to_search_data(activity.object)

    if activity.data["type"] == "Create" and maybe_search_data do
      with {:ok, embedding} <- get_embedding(maybe_search_data.content),
           {:ok, %{status: 200}} <-
             QdrantClient.put(
               "/collections/posts/points",
               build_index_payload(activity, embedding)
             ) do
        :ok
      else
        e -> {:error, e}
      end
    else
      :ok
    end
  end

  @impl true
  def remove_from_index(object) do
    activity = Activity.get_by_object_ap_id_with_object(object.data["id"])
    id = activity.id |> FlakeId.from_string() |> Ecto.UUID.cast!()

    with {:ok, %{status: 200}} <-
           QdrantClient.post("/collections/posts/points/delete", %{"points" => [id]}) do
      :ok
    else
      e -> {:error, e}
    end
  end

  @impl true
  def search(user, original_query, options) do
    query = "Represent this sentence for searching relevant passages: #{original_query}"

    with {:ok, embedding} <- get_embedding(query),
         {:ok, %{body: %{"result" => result}}} <-
           QdrantClient.post(
             "/collections/posts/points/search",
             build_search_payload(embedding, options)
           ) do
      ids =
        Enum.map(result, fn %{"id" => id} ->
          Ecto.UUID.dump!(id)
        end)

      from(a in Activity, where: a.id in ^ids)
      |> Activity.with_preloaded_object()
      |> Activity.restrict_deactivated_users()
      |> Ecto.Query.order_by([a], fragment("array_position(?, ?)", ^ids, a.id))
      |> Pleroma.Repo.all()
      |> maybe_fetch(user, original_query)
    else
      _ ->
        []
    end
  end

  @impl true
  def healthcheck_endpoints do
    qdrant_health =
      Config.get([Pleroma.Search.QdrantSearch, :qdrant_url])
      |> URI.parse()
      |> Map.put(:path, "/healthz")
      |> URI.to_string()

    openai_health = Config.get([Pleroma.Search.QdrantSearch, :openai_healthcheck_url])

    [qdrant_health, openai_health] |> Enum.filter(& &1)
  end
end

defmodule Pleroma.Search.QdrantSearch.OpenAIClient do
  use Tesla
  alias Pleroma.Config.Getting, as: Config

  plug(Tesla.Middleware.BaseUrl, Config.get([Pleroma.Search.QdrantSearch, :openai_url]))
  plug(Tesla.Middleware.JSON)

  plug(Tesla.Middleware.Headers, [
    {"Authorization",
     "Bearer #{Pleroma.Config.get([Pleroma.Search.QdrantSearch, :openai_api_key])}"}
  ])
end

defmodule Pleroma.Search.QdrantSearch.QdrantClient do
  use Tesla
  alias Pleroma.Config.Getting, as: Config

  plug(Tesla.Middleware.BaseUrl, Config.get([Pleroma.Search.QdrantSearch, :qdrant_url]))
  plug(Tesla.Middleware.JSON)

  plug(Tesla.Middleware.Headers, [
    {"api-key", Pleroma.Config.get([Pleroma.Search.QdrantSearch, :qdrant_api_key])}
  ])
end
