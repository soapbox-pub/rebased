defmodule Pleroma.Activity do
  use Ecto.Schema
  alias Pleroma.{Repo, Activity}
  import Ecto.Query

  schema "activities" do
    field :data, :map

    timestamps()
  end

  def get_by_ap_id(ap_id) do
    Repo.one(from activity in Activity,
      where: fragment("? @> ?", activity.data, ^%{id: ap_id}))
  end

  def all_by_object_ap_id(ap_id) do
    Repo.all(from activity in Activity,
      where: fragment("? @> ?", activity.data, ^%{object: %{id: ap_id}}))
  end
end
