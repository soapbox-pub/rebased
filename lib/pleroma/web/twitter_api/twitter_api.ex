defmodule Pleroma.Web.TwitterAPI.TwitterAPI do
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Repo
  alias Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter

  def create_status(user = %User{}, data = %{}) do
    activity = %{
      "type" => "Create",
      "to" => [
        User.ap_followers(user),
        "https://www.w3.org/ns/activitystreams#Public"
      ],
      "actor" => User.ap_id(user),
      "object" => %{
        "type" => "Note",
        "content" => data["status"]
      }
    }

    ActivityPub.insert(activity)
  end

  def fetch_public_statuses do
    activities = ActivityPub.fetch_public_activities

    Enum.map(activities, fn(activity) ->
      actor = get_in(activity.data, ["actor"])
      user = Repo.get_by!(User, ap_id: actor)
      ActivityRepresenter.to_map(activity, %{user: user})
    end)
  end
end
