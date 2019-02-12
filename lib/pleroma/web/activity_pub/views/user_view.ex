# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.UserView do
  use Pleroma.Web, :view

  alias Pleroma.Web.WebFinger
  alias Pleroma.Web.Salmon
  alias Pleroma.User
  alias Pleroma.Repo
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils

  import Ecto.Query

  def render("endpoints.json", %{user: %{local: true} = _user}) do
    %{
      "oauthAuthorizationEndpoint" => "#{Pleroma.Web.Endpoint.url()}/oauth/authorize",
      "oauthTokenEndpoint" => "#{Pleroma.Web.Endpoint.url()}/oauth/token"
    }
    |> Map.merge(render("endpoints.json", nil))
  end

  def render("endpoints.json", _) do
    %{
      "sharedInbox" => "#{Pleroma.Web.Endpoint.url()}/inbox"
    }
  end

  # the instance itself is not a Person, but instead an Application
  def render("user.json", %{user: %{nickname: nil} = user}) do
    {:ok, user} = WebFinger.ensure_keys_present(user)
    {:ok, _, public_key} = Salmon.keys_from_pem(user.info.keys)
    public_key = :public_key.pem_entry_encode(:SubjectPublicKeyInfo, public_key)
    public_key = :public_key.pem_encode([public_key])

    endpoints = render("endpoints.json", %{user: user})

    %{
      "id" => user.ap_id,
      "type" => "Application",
      "following" => "#{user.ap_id}/following",
      "followers" => "#{user.ap_id}/followers",
      "inbox" => "#{user.ap_id}/inbox",
      "name" => "Pleroma",
      "summary" => "Virtual actor for Pleroma relay",
      "url" => user.ap_id,
      "manuallyApprovesFollowers" => false,
      "publicKey" => %{
        "id" => "#{user.ap_id}#main-key",
        "owner" => user.ap_id,
        "publicKeyPem" => public_key
      },
      "endpoints" => endpoints
    }
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("user.json", %{user: user}) do
    {:ok, user} = WebFinger.ensure_keys_present(user)
    {:ok, _, public_key} = Salmon.keys_from_pem(user.info.keys)
    public_key = :public_key.pem_entry_encode(:SubjectPublicKeyInfo, public_key)
    public_key = :public_key.pem_encode([public_key])

    endpoints = render("endpoints.json", %{user: user})

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
      "manuallyApprovesFollowers" => user.info.locked,
      "publicKey" => %{
        "id" => "#{user.ap_id}#main-key",
        "owner" => user.ap_id,
        "publicKeyPem" => public_key
      },
      "endpoints" => endpoints,
      "icon" => %{
        "type" => "Image",
        "url" => User.avatar_url(user)
      },
      "image" => %{
        "type" => "Image",
        "url" => User.banner_url(user)
      },
      "tag" => user.info.source_data["tag"] || []
    }
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("following.json", %{user: user, page: page}) do
    query = User.get_friends_query(user)
    query = from(user in query, select: [:ap_id])
    following = Repo.all(query)

    collection(following, "#{user.ap_id}/following", page, !user.info.hide_follows)
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("following.json", %{user: user}) do
    query = User.get_friends_query(user)
    query = from(user in query, select: [:ap_id])
    following = Repo.all(query)

    %{
      "id" => "#{user.ap_id}/following",
      "type" => "OrderedCollection",
      "totalItems" => length(following),
      "first" => collection(following, "#{user.ap_id}/following", 1, !user.info.hide_follows)
    }
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("followers.json", %{user: user, page: page}) do
    query = User.get_followers_query(user)
    query = from(user in query, select: [:ap_id])
    followers = Repo.all(query)

    collection(followers, "#{user.ap_id}/followers", page, !user.info.hide_followers)
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("followers.json", %{user: user}) do
    query = User.get_followers_query(user)
    query = from(user in query, select: [:ap_id])
    followers = Repo.all(query)

    %{
      "id" => "#{user.ap_id}/followers",
      "type" => "OrderedCollection",
      "totalItems" => length(followers),
      "first" => collection(followers, "#{user.ap_id}/followers", 1, !user.info.hide_followers)
    }
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("outbox.json", %{user: user, max_id: max_qid}) do
    # XXX: technically note_count is wrong for this, but it's better than nothing
    info = User.user_info(user)

    params = %{
      "limit" => "10"
    }

    params =
      if max_qid != nil do
        Map.put(params, "max_id", max_qid)
      else
        params
      end

    activities = ActivityPub.fetch_user_activities(user, nil, params)
    min_id = Enum.at(Enum.reverse(activities), 0).id
    max_id = Enum.at(activities, 0).id

    collection =
      Enum.map(activities, fn act ->
        {:ok, data} = Transmogrifier.prepare_outgoing(act.data)
        data
      end)

    iri = "#{user.ap_id}/outbox"

    page = %{
      "id" => "#{iri}?max_id=#{max_id}",
      "type" => "OrderedCollectionPage",
      "partOf" => iri,
      "totalItems" => info.note_count,
      "orderedItems" => collection,
      "next" => "#{iri}?max_id=#{min_id}"
    }

    if max_qid == nil do
      %{
        "id" => iri,
        "type" => "OrderedCollection",
        "totalItems" => info.note_count,
        "first" => page
      }
      |> Map.merge(Utils.make_json_ld_header())
    else
      page |> Map.merge(Utils.make_json_ld_header())
    end
  end

  def render("inbox.json", %{user: user, max_id: max_qid}) do
    params = %{
      "limit" => "10"
    }

    params =
      if max_qid != nil do
        Map.put(params, "max_id", max_qid)
      else
        params
      end

    activities = ActivityPub.fetch_activities([user.ap_id | user.following], params)

    min_id = Enum.at(Enum.reverse(activities), 0).id
    max_id = Enum.at(activities, 0).id

    collection =
      Enum.map(activities, fn act ->
        {:ok, data} = Transmogrifier.prepare_outgoing(act.data)
        data
      end)

    iri = "#{user.ap_id}/inbox"

    page = %{
      "id" => "#{iri}?max_id=#{max_id}",
      "type" => "OrderedCollectionPage",
      "partOf" => iri,
      "totalItems" => -1,
      "orderedItems" => collection,
      "next" => "#{iri}?max_id=#{min_id}"
    }

    if max_qid == nil do
      %{
        "id" => iri,
        "type" => "OrderedCollection",
        "totalItems" => -1,
        "first" => page
      }
      |> Map.merge(Utils.make_json_ld_header())
    else
      page |> Map.merge(Utils.make_json_ld_header())
    end
  end

  def collection(collection, iri, page, show_items \\ true, total \\ nil) do
    offset = (page - 1) * 10
    items = Enum.slice(collection, offset, 10)
    items = Enum.map(items, fn user -> user.ap_id end)
    total = total || length(collection)

    map = %{
      "id" => "#{iri}?page=#{page}",
      "type" => "OrderedCollectionPage",
      "partOf" => iri,
      "totalItems" => total,
      "orderedItems" => if(show_items, do: items, else: [])
    }

    if offset < total do
      Map.put(map, "next", "#{iri}?page=#{page + 1}")
    else
      map
    end
  end
end
