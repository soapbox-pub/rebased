defmodule Pleroma.Web.TwitterAPI.UserView do
  use Pleroma.Web, :view
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MediaProxy

  def render("show.json", %{user: user = %User{}} = assigns) do
    render_one(user, Pleroma.Web.TwitterAPI.UserView, "user.json", assigns)
  end

  def render("index.json", %{users: users, for: user}) do
    render_many(users, Pleroma.Web.TwitterAPI.UserView, "user.json", for: user)
  end

  def render("user.json", %{user: user = %User{}} = assigns) do
    image = User.avatar_url(user) |> MediaProxy.url()
    {following, follows_you, statusnet_blocking} = if assigns[:for] do
      {
        User.following?(assigns[:for], user),
        User.following?(user, assigns[:for]),
        User.blocks?(assigns[:for], user)
      }
    else
      {false, false, false}
    end

    user_info = User.get_cached_user_info(user)

    %{
      "created_at" => user.inserted_at |> Utils.format_naive_asctime,
      "description" => HtmlSanitizeEx.strip_tags(user.bio),
      "favourites_count" => 0,
      "followers_count" => user_info[:follower_count],
      "following" => following,
      "follows_you" => follows_you,
      "statusnet_blocking" => statusnet_blocking,
      "friends_count" => user_info[:following_count],
      "id" => user.id,
      "name" => user.name,
      "profile_image_url" => image,
      "profile_image_url_https" => image,
      "profile_image_url_profile_size" => image,
      "profile_image_url_original" => image,
      "rights" => %{},
      "screen_name" => user.nickname,
      "statuses_count" => user_info[:note_count],
      "statusnet_profile_url" => user.ap_id,
      "cover_photo" => image_url(user.info["banner"]) |> MediaProxy.url(),
      "background_image" => image_url(user.info["background"]) |> MediaProxy.url(),
    }
  end

  def render("short.json", %{user: %User{
                               nickname: nickname, id: id, ap_id: ap_id, name: name
                           }}) do
    %{
      "fullname" => name,
      "id" => id,
      "ostatus_uri" => ap_id,
      "profile_url" => ap_id,
      "screen_name" => nickname
    }
  end

  defp image_url(%{"url" => [ %{ "href" => href } | _ ]}), do: href
  defp image_url(_), do: nil
end
