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
end
