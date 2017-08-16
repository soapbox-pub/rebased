defmodule Pleroma.Activity do
  use Ecto.Schema
  alias Pleroma.{Repo, Activity}
  import Ecto.Query

  schema "activities" do
    field :data, :map
    field :local, :boolean, default: true

    timestamps()
  end

  def get_by_ap_id(ap_id) do
    Repo.one(from activity in Activity,
      where: fragment("(?)->>'id' = ?", activity.data, ^to_string(ap_id)))
  end

  # Wrong name, only returns create activities
  def all_by_object_ap_id_q(ap_id) do
    from activity in Activity,
      where: fragment("(?)->'object'->>'id' = ?", activity.data, ^to_string(ap_id))
  end

  def all_non_create_by_object_ap_id_q(ap_id) do
    from activity in Activity,
      where: fragment("(?)->>'object' = ?", activity.data, ^to_string(ap_id))
  end

  def all_by_object_ap_id(ap_id) do
    Repo.all(all_by_object_ap_id_q(ap_id))
  end

  def get_create_activity_by_object_ap_id(ap_id) do
    Repo.one(from activity in Activity,
      where: fragment("(?)->'object'->>'id' = ?", activity.data, ^to_string(ap_id))
             and fragment("(?)->>'type' = 'Create'", activity.data))
  end
end
