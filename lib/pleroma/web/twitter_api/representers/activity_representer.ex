defmodule Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter do
  use Pleroma.Web.TwitterAPI.Representers.BaseRepresenter
  alias Pleroma.Web.TwitterAPI.Representers.UserRepresenter
  alias Pleroma.Activity

  def to_map(%Activity{} = activity, %{user: user} = opts) do
    content = get_in(activity.data, ["object", "content"])
    published = get_in(activity.data, ["object", "published"])
    %{
      "id" => activity.id,
      "user" => UserRepresenter.to_map(user, opts),
      "attentions" => [],
      "statusnet_html" => content,
      "text" => content,
      "is_local" => true,
      "is_post_verb" => true,
      "created_at" => published
    }
  end
end
