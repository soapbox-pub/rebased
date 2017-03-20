defmodule Pleroma.Web.TwitterAPI.Representers.UserRepresenter do
  use Pleroma.Web.TwitterAPI.Representers.BaseRepresenter

  def to_map(user, options) do
    image = "https://placehold.it/48x48"
    map = %{
      "id" => user.id,
      "name" => user.name,
      "screen_name" => user.nickname,
      "description" => user.bio,
      "following" => false,
      # Fake fields
      "favourites_count" => 0,
      "statuses_count" => 0,
      "friends_count" => 0,
      "followers_count" => 0,
      "profile_image_url" => image,
      "profile_image_url_https" => image,
      "profile_image_url_profile_size" => image,
      "profile_image_url_original" => image,
      "rights" => %{}
    }

    map
  end
end
