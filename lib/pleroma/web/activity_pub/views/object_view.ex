defmodule Pleroma.Web.ActivityPub.ObjectView do
  use Pleroma.Web, :view
  alias Pleroma.Web.ActivityPub.Transmogrifier

  def render("object.json", %{object: object}) do
    base = %{
      "@context" => [
        "https://www.w3.org/ns/activitystreams",
        "https://w3id.org/security/v1",
        %{
          "manuallyApprovesFollowers" => "as:manuallyApprovesFollowers",
          "sensitive" => "as:sensitive",
          "Hashtag" => "as:Hashtag",
          "ostatus" => "http://ostatus.org#",
          "atomUri" => "ostatus:atomUri",
          "inReplyToAtomUri" => "ostatus:inReplyToAtomUri",
          "conversation" => "ostatus:conversation",
          "toot" => "http://joinmastodon.org/ns#",
          "Emoji" => "toot:Emoji"
        }
      ]
    }

    additional = Transmogrifier.prepare_object(object.data)
    Map.merge(base, additional)
  end
end
