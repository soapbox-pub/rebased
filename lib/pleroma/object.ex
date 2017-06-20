defmodule Pleroma.Object do
  use Ecto.Schema
  alias Pleroma.{Repo, Object}
  import Ecto.{Query, Changeset}

  schema "objects" do
    field :data, :map

    timestamps()
  end

  def create(data) do
    Object.change(%Object{}, %{data: data})
    |> Repo.insert
  end

  def change(struct, params \\ %{}) do
    changeset = struct
    |> cast(params, [:data])
    |> validate_required([:data])
    |> unique_constraint(:ap_id, name: :objects_unique_apid_index)
  end

  def get_by_ap_id(ap_id) do
    Repo.one(from object in Object,
      where: fragment("? @> ?", object.data, ^%{id: ap_id}))
  end

  def get_cached_by_ap_id(ap_id) do
    if Mix.env == :test do
      get_by_ap_id(ap_id)
    else
      key = "object:#{ap_id}"
      Cachex.get!(:user_cache, key, fallback: fn(_) ->
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
end
