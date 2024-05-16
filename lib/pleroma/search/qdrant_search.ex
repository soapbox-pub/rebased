defmodule Pleroma.Search.QdrantSearch do
  @behaviour Pleroma.Search.SearchBackend
  import Ecto.Query
  alias Pleroma.Activity

  alias __MODULE__.QdrantClient
  alias __MODULE__.OllamaClient

  import Pleroma.Search.Meilisearch, only: [object_to_search_data: 1]

  @impl true
  def create_index() do
    payload = Pleroma.Config.get([Pleroma.Search.QdrantSearch, :qdrant_index_configuration])

    with {:ok, %{status: 200}} <- QdrantClient.put("/collections/posts", payload) do
      :ok
    else
      e -> {:error, e}
    end
  end

  @impl true
  def drop_index() do
    with {:ok, %{status: 200}} <- QdrantClient.delete("/collections/posts") do
      :ok
    else
      e -> {:error, e}
    end
  end

  def get_embedding(text) do
    with {:ok, %{body: %{"embedding" => embedding}}} <-
           OllamaClient.post("/api/embeddings", %{
             prompt: text,
             model: Pleroma.Config.get([Pleroma.Search.QdrantSearch, :ollama_model])
           }) do
      {:ok, embedding}
    else
      _ ->
        {:error, "Failed to get embedding"}
    end
  end

  defp build_index_payload(activity, embedding) do
    %{
      points: [
        %{
          id: activity.id |> FlakeId.from_string() |> Ecto.UUID.cast!(),
          vector: embedding
        }
      ]
    }
  end

  defp build_search_payload(embedding) do
    %{
      vector: embedding,
      limit: 20
    }
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
  def search(_user, query, _options) do
    query = "Represent this sentence for searching relevant passages: #{query}"

    with {:ok, embedding} <- get_embedding(query),
         {:ok, %{body: %{"result" => result}}} <-
           QdrantClient.post("/collections/posts/points/search", build_search_payload(embedding)) do
      ids =
        Enum.map(result, fn %{"id" => id} ->
          Ecto.UUID.dump!(id)
        end)

      from(a in Activity, where: a.id in ^ids)
      |> Activity.with_preloaded_object()
      |> Activity.restrict_deactivated_users()
      |> Ecto.Query.order_by([a], fragment("array_position(?, ?)", ^ids, a.id))
      |> Pleroma.Repo.all()
    else
      _ ->
        []
    end
  end

  @impl true
  def remove_from_index(_object) do
    :ok
  end
end

defmodule Pleroma.Search.QdrantSearch.OllamaClient do
  use Tesla

  plug(Tesla.Middleware.BaseUrl, Pleroma.Config.get([Pleroma.Search.QdrantSearch, :ollama_url]))
  plug(Tesla.Middleware.JSON)
end

defmodule Pleroma.Search.QdrantSearch.QdrantClient do
  use Tesla

  plug(Tesla.Middleware.BaseUrl, Pleroma.Config.get([Pleroma.Search.QdrantSearch, :qdrant_url]))
  plug(Tesla.Middleware.JSON)

  plug(Tesla.Middleware.Headers, [
    {"api-key", Pleroma.Config.get([Pleroma.Search.QdrantSearch, :qdrant_api_key])}
  ])
end
