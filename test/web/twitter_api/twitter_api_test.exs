defmodule Pleroma.Web.TwitterAPI.TwitterAPITest do
  use Pleroma.DataCase
  alias Pleroma.Builders.{UserBuilder, ActivityBuilder}
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.{Activity, User}
  alias Pleroma.Web.TwitterAPI.Representers.{UserRepresenter, ActivityRepresenter}
  alias Pleroma.Web.ActivityPub.ActivityPub

  test "create a status" do
    user = UserBuilder.build
    input = %{
      status: "Hello again."
    }

    { :ok, activity = %Activity{} } = TwitterAPI.create_status(user, input)

    assert get_in(activity.data, [:object, :content]) == "Hello again."
    assert get_in(activity.data, [:object, :type]) == "Note"
    assert get_in(activity.data, [:actor]) == User.ap_id(user)
    assert Enum.member?(get_in(activity.data, [:to]), User.ap_followers(user))
    assert Enum.member?(get_in(activity.data, [:to]), "https://www.w3.org/ns/activitystreams#Public")
  end

  test "fetch public activities" do
    %{ public: activity, user: user } = ActivityBuilder.public_and_non_public
    statuses = TwitterAPI.fetch_public_statuses()

    assert length(statuses) == 1
    assert Enum.at(statuses, 0) == ActivityRepresenter.to_map(activity, %{user: user})
  end
end
