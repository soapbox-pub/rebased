defmodule Pleroma.Web.TwitterAPI.UserView do
  use Pleroma.Web, :view
  alias Pleroma.User
  alias Pleroma.Formatter
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

    {following, follows_you, statusnet_blocking} =
      if assigns[:for] do
        {
          User.following?(assigns[:for], user),
          User.following?(user, assigns[:for]),
          User.blocks?(assigns[:for], user)
        }
      else
        {false, false, false}
      end

    user_info = User.get_cached_user_info(user)

    emoji =
      (user.info["source_data"]["tag"] || [])
      |> Enum.filter(fn %{"type" => t} -> t == "Emoji" end)
      |> Enum.map(fn %{"icon" => %{"url" => url}, "name" => name} ->
        {String.trim(name, ":"), url}
      end)

    bio = HtmlSanitizeEx.strip_tags(user.bio)

    data = %{
      "created_at" => user.inserted_at |> Utils.format_naive_asctime(),
      "description" => bio,
      "description_html" => bio |> Formatter.emojify(emoji),
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
      "rights" => %{
        "delete_others_notice" => !!user.info["is_moderator"]
      },
      "screen_name" => user.nickname,
      "screen_name_html" => Formatter.emojify(user.nickname, emoji),
      "statuses_count" => user_info[:note_count],
      "statusnet_profile_url" => user.ap_id,
      "cover_photo" => User.banner_url(user) |> MediaProxy.url(),
      "background_image" => image_url(user.info["background"]) |> MediaProxy.url(),
      "is_local" => user.local,
      "locked" => !!user.info["locked"],
      "default_scope" => user.info["default_scope"] || "public"
    }

    if assigns[:token] do
      Map.put(data, "token", assigns[:token])
    else
      data
    end
  end

  def render("short.json", %{
        user: %User{
          nickname: nickname,
          id: id,
          ap_id: ap_id,
          name: name
        }
      }) do
    %{
      "fullname" => name,
      "id" => id,
      "ostatus_uri" => ap_id,
      "profile_url" => ap_id,
      "screen_name" => nickname
    }
  end

  defp image_url(%{"url" => [%{"href" => href} | _]}), do: href
  defp image_url(_), do: nil
end
