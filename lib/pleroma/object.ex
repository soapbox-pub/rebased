defmodule Pleroma.Object do
  use Ecto.Schema
  alias Pleroma.{Repo, Object, User, Activity}
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

  def normalize(obj) when is_map(obj), do: Object.get_by_ap_id(obj["id"])
  def normalize(ap_id) when is_binary(ap_id), do: Object.get_by_ap_id(ap_id)
  def normalize(_), do: nil

  # Owned objects can only be mutated by their owner
  def authorize_mutation(%Object{data: %{"actor" => actor}}, %User{ap_id: ap_id}),
    do: actor == ap_id

  # Legacy objects can be mutated by anybody
  def authorize_mutation(%Object{}, %User{}), do: true

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

  def get_tombstone(%Object{data: data}, deleted \\ DateTime.utc_now()) do
    %{
      id: data["id"],
      type: "tombstone",
      deleted: deleted
    }
  end

  def swap_data_with_tombstone(object) do
    tombstone = get_tombstone(object)

    object
    |> Object.change(%{data: tombstone})
    |> Repo.update()
  end

  def delete(%Object{data: %{"id" => id}} = object) do
    with swap_data_with_tombstone(object),
         Activity.all_non_create_by_object_ap_id_q(id)
         |> Repo.all()
         |> Enum.each(&Activity.swap_data_with_tombstone/1),
         {:ok, true} <- Cachex.del(:object_cache, "object:#{id}") do
      {:ok, object}
    end
  end
end
