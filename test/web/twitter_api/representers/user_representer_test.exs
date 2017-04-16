defmodule Pleroma.Web.TwitterAPI.Representers.UserRepresenterTest do
  use Pleroma.DataCase

  alias Pleroma.User
  alias Pleroma.Web.TwitterAPI.Representers.UserRepresenter
  alias Pleroma.Builders.UserBuilder

  import Pleroma.Factory

  setup do
    user = insert(:user)
    [user: user]
  end

  test "A user with an avatar object", %{user: user} do
    image = "image"
    user = %{ user | avatar: %{ "url" => [%{"href" => image}] }}
    represented = UserRepresenter.to_map(user)
    assert represented["profile_image_url"] == image
  end

  test "A user", %{user: user} do
    image = "https://placehold.it/48x48"

    represented = %{
      "id" => user.id,
      "name" => user.name,
      "screen_name" => user.nickname,
      "description" => user.bio,
      # Fake fields
      "favourites_count" => 0,
      "statuses_count" => 0,
      "friends_count" => 0,
      "followers_count" => 0,
      "profile_image_url" => image,
      "profile_image_url_https" => image,
      "profile_image_url_profile_size" => image,
      "profile_image_url_original" => image,
      "following" => false,
      "rights" => %{}
    }

    assert represented == UserRepresenter.to_map(user)
  end

  test "A user for a given other follower", %{user: user} do
    {:ok, follower} = UserBuilder.insert(%{following: [User.ap_followers(user)]})
    image = "https://placehold.it/48x48"
    represented = %{
      "id" => user.id,
      "name" => user.name,
      "screen_name" => user.nickname,
      "description" => user.bio,
      # Fake fields
      "favourites_count" => 0,
      "statuses_count" => 0,
      "friends_count" => 0,
      "followers_count" => 0,
      "profile_image_url" => image,
      "profile_image_url_https" => image,
      "profile_image_url_profile_size" => image,
      "profile_image_url_original" => image,
      "following" => true,
      "rights" => %{}
    }

    assert represented == UserRepresenter.to_map(user, %{for: follower})
  end
end
