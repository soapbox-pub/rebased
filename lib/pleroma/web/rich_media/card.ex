defmodule Pleroma.Web.RichMedia.Card do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Activity
  alias Pleroma.HTML
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Web.RichMedia.Parser
  alias Pleroma.Workers.RichMediaWorker

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)
  @config_impl Application.compile_env(:pleroma, [__MODULE__, :config_impl], Pleroma.Config)

  @type t :: %__MODULE__{}

  schema "rich_media_card" do
    field(:url_hash, :binary)
    field(:fields, :map)

    timestamps()
  end

  @doc false
  def changeset(card, attrs) do
    card
    |> cast(attrs, [:url_hash, :fields])
    |> validate_required([:url_hash, :fields])
    |> unique_constraint(:url_hash)
  end

  @spec create(String.t(), map()) :: {:ok, t()}
  def create(url, fields) do
    url_hash = url_to_hash(url)

    fields = Map.put_new(fields, "url", url)

    %__MODULE__{}
    |> changeset(%{url_hash: url_hash, fields: fields})
    |> Repo.insert(on_conflict: {:replace, [:fields]}, conflict_target: :url_hash)
  end

  @spec delete(String.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()} | :ok
  def delete(url) do
    url_hash = url_to_hash(url)
    @cachex.del(:rich_media_cache, url_hash)

    case get_by_url(url) do
      %__MODULE__{} = card -> Repo.delete(card)
      nil -> :ok
    end
  end

  @spec get_by_url(String.t() | nil) :: t() | nil | :error
  def get_by_url(url) when is_binary(url) do
    if @config_impl.get([:rich_media, :enabled]) do
      url_hash = url_to_hash(url)

      @cachex.fetch!(:rich_media_cache, url_hash, fn _ ->
        result =
          __MODULE__
          |> where(url_hash: ^url_hash)
          |> Repo.one()

        case result do
          %__MODULE__{} = card -> {:commit, card}
          _ -> {:ignore, nil}
        end
      end)
    else
      :error
    end
  end

  def get_by_url(nil), do: nil

  @spec get_or_backfill_by_url(String.t(), keyword()) :: t() | nil
  def get_or_backfill_by_url(url, opts \\ []) do
    if @config_impl.get([:rich_media, :enabled]) do
      case get_by_url(url) do
        %__MODULE__{} = card ->
          card

        nil ->
          activity_id = Keyword.get(opts, :activity_id, nil)

          RichMediaWorker.new(%{"op" => "backfill", "url" => url, "activity_id" => activity_id})
          |> Oban.insert()

          nil

        :error ->
          nil
      end
    else
      nil
    end
  end

  @spec get_by_object(Object.t()) :: t() | nil | :error
  def get_by_object(object) do
    case HTML.extract_first_external_url_from_object(object) do
      nil -> nil
      url -> get_or_backfill_by_url(url)
    end
  end

  @spec get_by_activity(Activity.t()) :: t() | nil | :error
  # Fake/Draft activity
  def get_by_activity(%Activity{id: "pleroma:fakeid"} = activity) do
    with {_, true} <- {:config, @config_impl.get([:rich_media, :enabled])},
         %Object{} = object <- Object.normalize(activity, fetch: false),
         url when not is_nil(url) <- HTML.extract_first_external_url_from_object(object) do
      case get_by_url(url) do
        # Cache hit
        %__MODULE__{} = card ->
          card

        # Cache miss, but fetch for rendering the Draft
        _ ->
          with {:ok, fields} <- Parser.parse(url),
               {:ok, card} <- create(url, fields) do
            card
          else
            _ -> nil
          end
      end
    else
      _ ->
        nil
    end
  end

  def get_by_activity(activity) do
    with %Object{} = object <- Object.normalize(activity, fetch: false),
         {_, nil} <- {:cached, get_cached_url(object, activity.id)} do
      nil
    else
      {:cached, url} ->
        get_or_backfill_by_url(url, activity_id: activity.id)

      _ ->
        :error
    end
  end

  @spec url_to_hash(String.t()) :: String.t()
  def url_to_hash(url) do
    :crypto.hash(:sha256, url) |> Base.encode16(case: :lower)
  end

  defp get_cached_url(object, activity_id) do
    key = "URL|#{activity_id}"

    @cachex.fetch!(:scrubber_cache, key, fn _ ->
      url = HTML.extract_first_external_url_from_object(object)
      Activity.HTML.add_cache_key_for(activity_id, key)

      {:commit, url}
    end)
  end
end
