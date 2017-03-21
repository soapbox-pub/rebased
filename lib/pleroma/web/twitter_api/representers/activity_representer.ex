defmodule Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter do
  use Pleroma.Web.TwitterAPI.Representers.BaseRepresenter
  alias Pleroma.Web.TwitterAPI.Representers.UserRepresenter

  def to_map(activity, %{user: user}) do
    content = get_in(activity.data, ["object", "content"])
    %{
      "id" => activity.id,
      "user" => UserRepresenter.to_map(user),
      "attentions" => [],
      "statusnet_html" => content,
      "text" => content,
      "is_local" => true,
      "is_post_verb" => true
    }
  end
end
