defmodule Pleroma.Web.ActivityPub.ObjectView do
  use Pleroma.Web, :view

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

    additional = Map.take(object.data, ["id", "to", "cc", "actor", "content", "summary", "type"])
    Map.merge(base, additional)
  end
end
