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
end
