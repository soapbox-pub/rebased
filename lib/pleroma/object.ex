defmodule Pleroma.Object do
  use Ecto.Schema
  alias Pleroma.{Repo, Object, Activity}
  alias Pleroma.Object.Fetcher
  import Ecto.{Query, Changeset}

  schema "objects" do
    field(:data, :map)

    timestamps()
  end

  def create(data) do
    Object.change(%Object{}, %{data: data})
    |> Repo.insert()
  end

  def change(struct, params \\ %{}) do
    struct
    |> cast(params, [:data])
    |> validate_required([:data])
    |> unique_constraint(:ap_id, name: :objects_unique_apid_index)
  end

  def get_by_ap_id(nil), do: nil

  def get_by_ap_id(ap_id) do
    Repo.one(from(object in Object, where: fragment("(?)->>'id' = ?", object.data, ^ap_id)))
  end

  def normalize(_, fetch_remote \\ true)

  def normalize(obj, fetch_remote) when is_map(obj), do: normalize(obj["id"], fetch_remote)
  def normalize(ap_id, true) when is_binary(ap_id), do: Fetcher.fetch_object_from_id!(ap_id)
  def normalize(ap_id, false) when is_binary(ap_id), do: get_cached_by_ap_id(ap_id)
  def normalize(obj, _), do: nil

  if Mix.env() == :test do
    def get_cached_by_ap_id(ap_id) do
      get_by_ap_id(ap_id)
    end
  else
    def get_cached_by_ap_id(ap_id) do
      key = "object:#{ap_id}"

      Cachex.fetch!(:object_cache, key, fn _ ->
        object = get_by_ap_id(ap_id)

        if object do
          {:commit, object}
        else
          {:ignore, object}
        end
      end)
    end
  end

  def context_mapping(context) do
    Object.change(%Object{}, %{data: %{"id" => context}})
  end

  def delete(%Object{data: %{"id" => id}} = object) do
    with Repo.delete(object),
         Repo.delete_all(Activity.all_non_create_by_object_ap_id_q(id)),
         {:ok, true} <- Cachex.del(:object_cache, "object:#{id}") do
      {:ok, object}
    end
  end
end
