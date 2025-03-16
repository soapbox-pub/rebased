defmodule Pleroma.Web.MastodonAPI.TagView do
  use Pleroma.Web, :view
  alias Pleroma.User
  alias Pleroma.Web.Router.Helpers

  def render("index.json", %{tags: tags, for_user: user}) do
    safe_render_many(tags, __MODULE__, "show.json", %{for_user: user})
  end

  def render("show.json", %{tag: tag, for_user: user}) do
    following =
      with %User{} <- user do
        User.following_hashtag?(user, tag)
      else
        _ -> false
      end

    %{
      name: tag.name,
      url: Helpers.tag_feed_url(Pleroma.Web.Endpoint, :feed, tag.name),
      history: [],
      following: following
    }
  end
end
