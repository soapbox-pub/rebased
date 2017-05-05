defmodule Pleroma.Web.TwitterAPI.Representers.UserRepresenter do
  use Pleroma.Web.TwitterAPI.Representers.BaseRepresenter

  alias Pleroma.User

  def to_map(user, opts) do
    image = User.avatar_url(user)
    following = if opts[:for] do
      User.following?(opts[:for], user)
    else
      false
    end

    user_info = User.get_cached_user_info(user)

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
      "rights" => %{},
      "statusnet_profile_url" => user.ap_id
    }

    map
  end
end
