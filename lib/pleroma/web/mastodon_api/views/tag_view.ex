defmodule Pleroma.Web.MastodonAPI.TagView do
  use Pleroma.Web, :view
  alias Pleroma.User
  alias Pleroma.Web.Router.Helpers

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
