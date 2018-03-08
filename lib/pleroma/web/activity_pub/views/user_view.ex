defmodule Pleroma.Web.ActivityPub.UserView do
  use Pleroma.Web, :view
  alias Pleroma.Web.Salmon
  alias Pleroma.Web.WebFinger
  alias Pleroma.User

  def render("user.json", %{user: user}) do
    {:ok, user} = WebFinger.ensure_keys_present(user)
    {:ok, _, public_key} = Salmon.keys_from_pem(user.info["keys"])
    public_key = :public_key.pem_entry_encode(:RSAPublicKey, public_key)
    public_key = :public_key.pem_encode([public_key])
    %{
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
      ],
      "id" => user.ap_id,
      "type" => "Person",
      "following" => "#{user.ap_id}/following",
      "followers" => "#{user.ap_id}/followers",
      "inbox" => "#{user.ap_id}/inbox",
      "outbox" => "#{user.ap_id}/outbox",
      "preferredUsername" => user.nickname,
      "name" => user.name,
      "summary" => user.bio,
      "url" => user.ap_id,
      "manuallyApprovesFollowers" => false,
      "publicKey" => %{
        "id" => "#{user.ap_id}#main-key",
        "owner" => user.ap_id,
        "publicKeyPem" => public_key
      },
      "endpoints" => %{
        "sharedInbox" => "#{Pleroma.Web.Endpoint.url}/inbox"
      },
      "icon" => %{
        "type" => "Image",
        "url" => User.avatar_url(user)
      },
      "image" => %{
        "type" => "Image",
        "url" => User.banner_url(user)
      }
    }
  end
end
