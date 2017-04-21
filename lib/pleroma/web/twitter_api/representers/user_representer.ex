defmodule Pleroma.Web.TwitterAPI.Representers.UserRepresenter do
  use Pleroma.Web.TwitterAPI.Representers.BaseRepresenter

  alias Pleroma.User

  def to_map(user, opts) do
    image = case user.avatar do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> "https://placehold.it/48x48"
    end

    following = if opts[:for] do
      User.following?(opts[:for], user)
    else
      false
    end

    user_info = User.user_info(user)

    map = %{
      "id" => user.id,
      "name" => user.name,
      "screen_name" => user.nickname,
      "description" => user.bio,
      "following" => following,
      # Fake fields
      "favourites_count" => 0,
      "statuses_count" => user_info[:note_count],
      "friends_count" => user_info[:following_count],
      "followers_count" => user_info[:follower_count],
      "profile_image_url" => image,
      "profile_image_url_https" => image,
      "profile_image_url_profile_size" => image,
      "profile_image_url_original" => image,
      "rights" => %{}
    }

    map
  end
end
