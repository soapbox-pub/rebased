defmodule Pleroma.Web.TwitterAPI.TwitterAPITest do
  use Pleroma.DataCase
  alias Pleroma.Builders.{UserBuilder, ActivityBuilder}
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.{Activity, User, Object, Repo}
  alias Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter

  test "create a status" do
    user = UserBuilder.build(%{ap_id: "142344"})
    _mentioned_user = UserBuilder.insert(%{nickname: "shp", ap_id: "shp"})

    object_data = %{
      "type" => "Image",
      "url" => [
        %{
          "type" => "Link",
          "mediaType" => "image/jpg",
          "href" => "http://example.org/image.jpg"
        }
      ],
      "uuid" => 1
    }

    object = Repo.insert!(%Object{data: object_data})

    input = %{
      "status" => "Hello again, @shp.<script></script>",
      "media_ids" => [object.id]
    }

    { :ok, activity = %Activity{} } = TwitterAPI.create_status(user, input)

    assert get_in(activity.data, ["object", "content"]) == "Hello again, <a href='shp'>@shp</a>."
    assert get_in(activity.data, ["object", "type"]) == "Note"
    assert get_in(activity.data, ["actor"]) == user.ap_id
    assert Enum.member?(get_in(activity.data, ["to"]), User.ap_followers(user))
    assert Enum.member?(get_in(activity.data, ["to"]), "https://www.w3.org/ns/activitystreams#Public")
    assert Enum.member?(get_in(activity.data, ["to"]), "shp")

    # Add a context + 'statusnet_conversation_id'
    assert is_binary(get_in(activity.data, ["context"]))
    assert is_binary(get_in(activity.data, ["object", "context"]))
    assert get_in(activity.data, ["object", "statusnetConversationId"]) == activity.id
    assert get_in(activity.data, ["statusnetConversationId"]) == activity.id

    assert is_list(activity.data["object"]["attachment"])
  end

  test "create a status that is a reply" do
    user = UserBuilder.build(%{ap_id: "some_cool_id"})
    input = %{
      "status" => "Hello again."
    }

    { :ok, activity = %Activity{} } = TwitterAPI.create_status(user, input)

    input = %{
      "status" => "Here's your (you).",
      "in_reply_to_status_id" => activity.id
    }

    { :ok, reply = %Activity{} } = TwitterAPI.create_status(user, input)

    assert get_in(reply.data, ["context"]) == get_in(activity.data, ["context"])
    assert get_in(reply.data, ["object", "context"]) == get_in(activity.data, ["object", "context"])
    assert get_in(reply.data, ["statusnetConversationId"]) == get_in(activity.data, ["statusnetConversationId"])
    assert get_in(reply.data, ["object", "statusnetConversationId"]) == get_in(activity.data, ["object", "statusnetConversationId"])
    assert get_in(reply.data, ["object", "inReplyTo"]) == get_in(activity.data, ["object", "id"])
    assert get_in(reply.data, ["object", "inReplyToStatusId"]) == activity.id
    assert Enum.member?(get_in(reply.data, ["to"]), "some_cool_id")
  end

  test "fetch public statuses" do
    %{ public: activity, user: user } = ActivityBuilder.public_and_non_public
    {:ok, follower } = UserBuilder.insert(%{name: "dude", ap_id: "idididid", following: [User.ap_followers(user)]})

    statuses = TwitterAPI.fetch_public_statuses(follower)

    assert length(statuses) == 1
    assert Enum.at(statuses, 0) == ActivityRepresenter.to_map(activity, %{user: user, for: follower})
  end

  test "fetch friends' statuses" do
    ActivityBuilder.public_and_non_public
    {:ok, activity} = ActivityBuilder.insert(%{"to" => ["someguy/followers"]})
    {:ok, user} = UserBuilder.insert(%{ap_id: "some other id", following: ["someguy/followers"]})

    statuses = TwitterAPI.fetch_friend_statuses(user)

    activity_user = Repo.get_by(User, ap_id: activity.data["actor"])

    assert length(statuses) == 1
    assert Enum.at(statuses, 0) == ActivityRepresenter.to_map(activity, %{user: activity_user})
  end

  test "fetch a single status" do
    {:ok, activity} = ActivityBuilder.insert()
    {:ok, user} = UserBuilder.insert()
    actor = Repo.get_by!(User, ap_id: activity.data["actor"])

    status = TwitterAPI.fetch_status(user, activity.id)

    assert status == ActivityRepresenter.to_map(activity, %{for: user, user: actor})
  end

  test "Follow another user" do
    { :ok, user } = UserBuilder.insert
    { :ok, following } = UserBuilder.insert(%{nickname: "guy"})

    {:ok, user, following, activity } = TwitterAPI.follow(user, following.id)

    user = Repo.get(User, user.id)
    follow = Repo.get(Activity, activity.id)

    assert user.following == [User.ap_followers(following)]
    assert follow == activity
  end

  test "Unfollow another user using user_id" do
    { :ok, following } = UserBuilder.insert(%{nickname: "guy"})
    { :ok, user } = UserBuilder.insert(%{following: [User.ap_followers(following)]})

    {:ok, user, _following } = TwitterAPI.unfollow(user, %{"user_id" => following.id})

    user = Repo.get(User, user.id)

    assert user.following == []
  end

  test "Unfollow another user using screen_name" do
    { :ok, following } = UserBuilder.insert(%{nickname: "guy"})
    { :ok, user } = UserBuilder.insert(%{following: [User.ap_followers(following)]})

    {:ok, user, _following } = TwitterAPI.unfollow(user, %{"screen_name" => following.nickname})

    user = Repo.get(User, user.id)

    assert user.following == []
  end

  test "fetch statuses in a context using the conversation id" do
    {:ok, user} = UserBuilder.insert()
    {:ok, activity} = ActivityBuilder.insert(%{"statusnetConversationId" => 1, "context" => "2hu"})
    {:ok, activity_two} = ActivityBuilder.insert(%{"statusnetConversationId" => 1,"context" => "2hu"})
    {:ok, _activity_three} = ActivityBuilder.insert(%{"context" => "3hu"})

    statuses = TwitterAPI.fetch_conversation(user, 1)

    assert length(statuses) == 2
    assert Enum.at(statuses, 0)["id"] == activity.id
    assert Enum.at(statuses, 1)["id"] == activity_two.id
  end

  test "upload a file" do
    file = %Plug.Upload{content_type: "image/jpg", path: Path.absname("test/fixtures/image.jpg"), filename: "an_image.jpg"}

    response = TwitterAPI.upload(file)

    assert is_binary(response)
  end

  test "it can parse mentions and return the relevant users" do
    text = "@gsimg According to @archaeme , that is @daggsy."

    {:ok, gsimg} = UserBuilder.insert(%{nickname: "gsimg"})
    {:ok, archaeme} = UserBuilder.insert(%{nickname: "archaeme"})

    expected_result = [
      {"@gsimg", gsimg},
      {"@archaeme", archaeme}
    ]

    assert TwitterAPI.parse_mentions(text) == expected_result
  end

  test "it adds user links to an existing text" do
    text = "@gsimg According to @archaeme , that is @daggsy."

    {:ok, _gsimg} = UserBuilder.insert(%{nickname: "gsimg", ap_id: "first_link" })
    {:ok, _archaeme} = UserBuilder.insert(%{nickname: "archaeme", ap_id: "second_link"})

    mentions = TwitterAPI.parse_mentions(text)
    expected_text = "<a href='first_link'>@gsimg</a> According to <a href='second_link'>@archaeme</a> , that is @daggsy."

    assert TwitterAPI.add_user_links(text, mentions) == expected_text
  end
end
