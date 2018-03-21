defmodule Pleroma.Web.ActivityPub.UserView do
  use Pleroma.Web, :view
  alias Pleroma.Web.Salmon
  alias Pleroma.Web.WebFinger
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Utils

  def render("user.json", %{user: user}) do
    {:ok, user} = WebFinger.ensure_keys_present(user)
    {:ok, _, public_key} = Salmon.keys_from_pem(user.info["keys"])
    public_key = :public_key.pem_entry_encode(:RSAPublicKey, public_key)
    public_key = :public_key.pem_encode([public_key])
    %{
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
    |> Map.merge(Utils.make_json_ld_header())
  end

  def collection(collection, iri, page) do
    offset = (page - 1) * 10
    items = Enum.slice(collection, offset, 10)
    items = Enum.map(items, fn (user) -> user.ap_id end)
    map = %{
      "id" => "#{iri}?page=#{page}",
      "type" => "OrderedCollectionPage",
      "partOf" => iri,
      "totalItems" => length(collection),
      "orderedItems" => items
    }
    if offset < length(collection) do
      Map.put(map, "next", "#{iri}?page=#{page+1}")
    end
  end

  def render("following.json", %{user: user, page: page}) do
    {:ok, following} = User.get_friends(user)
    collection(following, "#{user.ap_id}/following", page)
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("following.json", %{user: user}) do
    {:ok, following} = User.get_friends(user)
    %{
      "id" => "#{user.ap_id}/following",
      "type" => "OrderedCollection",
      "totalItems" => length(following),
      "first" => collection(following, "#{user.ap_id}/following", 1)
    }
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("followers.json", %{user: user, page: page}) do
    {:ok, followers} = User.get_followers(user)
    collection(followers, "#{user.ap_id}/followers", page)
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("followers.json", %{user: user}) do
    {:ok, followers} = User.get_followers(user)
    %{
      "id" => "#{user.ap_id}/following",
      "type" => "OrderedCollection",
      "totalItems" => length(followers),
      "first" => collection(followers, "#{user.ap_id}/followers", 1)
    }
    |> Map.merge(Utils.make_json_ld_header())
  end
end
