defmodule Pleroma.Web.CommonAPI do
  alias Pleroma.{Repo, Activity, Object}
  alias Pleroma.Web.ActivityPub.ActivityPub

  def delete(activity_id, user) do
    with %Activity{data: %{"object" => %{"id" => object_id}}} <- Repo.get(Activity, activity_id),
         %Object{} = object <- Object.get_by_ap_id(object_id),
           true <- user.ap_id == object.data["actor"],
         {:ok, delete} <- ActivityPub.delete(object) do
      {:ok, delete}
    end
  end

  def repeat(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         false <- activity.data["actor"] == user.ap_id,
         object <- Object.get_by_ap_id(activity.data["object"]["id"]) do
      ActivityPub.announce(user, object)
    else
      _ ->
        {:error, "Could not repeat"}
    end
  end

  def favorite(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         false <- activity.data["actor"] == user.ap_id,
         object <- Object.get_by_ap_id(activity.data["object"]["id"]) do
      ActivityPub.like(user, object)
    else
      _ ->
        {:error, "Could not favorite"}
    end
  end

  def unfavorite(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         false <- activity.data["actor"] == user.ap_id,
         object <- Object.get_by_ap_id(activity.data["object"]["id"]) do
      ActivityPub.unlike(user, object)
    else
      _ ->
        {:error, "Could not unfavorite"}
    end
  end

  # This is a hack for twidere.
  def get_by_id_or_ap_id(id) do
    activity = Repo.get(Activity, id) || Activity.get_create_activity_by_object_ap_id(id)
    if activity.data["type"] == "Create" do
      activity
    else
      Activity.get_create_activity_by_object_ap_id(activity.data["object"])
    end
  end
end
