defmodule Pleroma.Object do
  use Ecto.Schema
  alias Pleroma.{Repo, Object}
  import Ecto.Query

  schema "objects" do
    field :data, :map

    timestamps()
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
      Cachex.get!(:user_cache, key, fallback: fn(_) -> get_by_ap_id(ap_id) end)
    end
  end

  def context_mapping(context) do
    %Object{data: %{"id" => context}}
  end
end
