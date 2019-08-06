# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.UserView do
  use Pleroma.Web, :view

  alias Pleroma.Keys
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Router.Helpers

  import Ecto.Query

  def render("endpoints.json", %{user: %User{nickname: nil, local: true} = _user}) do
    %{"sharedInbox" => Helpers.activity_pub_url(Endpoint, :inbox)}
  end

  def render("endpoints.json", %{user: %User{local: true} = _user}) do
    %{
      "oauthAuthorizationEndpoint" => Helpers.o_auth_url(Endpoint, :authorize),
      "oauthRegistrationEndpoint" => Helpers.mastodon_api_url(Endpoint, :create_app),
      "oauthTokenEndpoint" => Helpers.o_auth_url(Endpoint, :token_exchange),
      "sharedInbox" => Helpers.activity_pub_url(Endpoint, :inbox)
    }
  end

  def render("endpoints.json", _), do: %{}

  def render("service.json", %{user: user}) do
    {:ok, user} = User.ensure_keys_present(user)
    {:ok, _, public_key} = Keys.keys_from_pem(user.info.keys)
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
      "summary" =>
        "An internal service actor for this Pleroma instance.  No user-serviceable parts inside.",
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

  # the instance itself is not a Person, but instead an Application
  def render("user.json", %{user: %User{nickname: nil} = user}),
    do: render("service.json", %{user: user})

  def render("user.json", %{user: %User{nickname: "internal." <> _} = user}),
    do: render("service.json", %{user: user}) |> Map.put("preferredUsername", user.nickname)

  def render("user.json", %{user: user}) do
    {:ok, user} = User.ensure_keys_present(user)
    {:ok, _, public_key} = Keys.keys_from_pem(user.info.keys)
    public_key = :public_key.pem_entry_encode(:SubjectPublicKeyInfo, public_key)
    public_key = :public_key.pem_encode([public_key])

    endpoints = render("endpoints.json", %{user: user})

    user_tags =
      user
      |> Transmogrifier.add_emoji_tags()
      |> Map.get("tag", [])

    fields =
      user.info
      |> User.Info.fields()
      |> Enum.map(fn %{"name" => name, "value" => value} ->
        %{
          "name" => Pleroma.HTML.strip_tags(name),
          "value" => Pleroma.HTML.filter_tags(value, Pleroma.HTML.Scrubber.LinksOnly)
        }
      end)
      |> Enum.map(&Map.put(&1, "type", "PropertyValue"))

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
      "attachment" => fields,
      "tag" => (user.info.source_data["tag"] || []) ++ user_tags
    }
    |> Map.merge(maybe_make_image(&User.avatar_url/2, "icon", user))
    |> Map.merge(maybe_make_image(&User.banner_url/2, "image", user))
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("following.json", %{user: user, page: page} = opts) do
    showing = (opts[:for] && opts[:for] == user) || !user.info.hide_follows
    query = User.get_friends_query(user)
    query = from(user in query, select: [:ap_id])
    following = Repo.all(query)

    total =
      if showing do
        length(following)
      else
        0
      end

    collection(following, "#{user.ap_id}/following", page, showing, total)
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("following.json", %{user: user} = opts) do
    showing = (opts[:for] && opts[:for] == user) || !user.info.hide_follows
    query = User.get_friends_query(user)
    query = from(user in query, select: [:ap_id])
    following = Repo.all(query)

    total =
      if showing do
        length(following)
      else
        0
      end

    %{
      "id" => "#{user.ap_id}/following",
      "type" => "OrderedCollection",
      "totalItems" => total,
      "first" =>
        if showing do
          collection(following, "#{user.ap_id}/following", 1, !user.info.hide_follows)
        else
          "#{user.ap_id}/following?page=1"
        end
    }
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("followers.json", %{user: user, page: page} = opts) do
    showing = (opts[:for] && opts[:for] == user) || !user.info.hide_followers

    query = User.get_followers_query(user)
    query = from(user in query, select: [:ap_id])
    followers = Repo.all(query)

    total =
      if showing do
        length(followers)
      else
        0
      end

    collection(followers, "#{user.ap_id}/followers", page, showing, total)
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("followers.json", %{user: user} = opts) do
    showing = (opts[:for] && opts[:for] == user) || !user.info.hide_followers

    query = User.get_followers_query(user)
    query = from(user in query, select: [:ap_id])
    followers = Repo.all(query)

    total =
      if showing do
        length(followers)
      else
        0
      end

    %{
      "id" => "#{user.ap_id}/followers",
      "type" => "OrderedCollection",
      "totalItems" => total,
      "first" =>
        if showing do
          collection(followers, "#{user.ap_id}/followers", 1, showing, total)
        else
          "#{user.ap_id}/followers?page=1"
        end
    }
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("outbox.json", %{user: user, max_id: max_qid}) do
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

    {max_id, min_id, collection} =
      if length(activities) > 0 do
        {
          Enum.at(Enum.reverse(activities), 0).id,
          Enum.at(activities, 0).id,
          Enum.map(activities, fn act ->
            {:ok, data} = Transmogrifier.prepare_outgoing(act.data)
            data
          end)
        }
      else
        {
          0,
          0,
          []
        }
      end

    iri = "#{user.ap_id}/outbox"

    page = %{
      "id" => "#{iri}?max_id=#{max_id}",
      "type" => "OrderedCollectionPage",
      "partOf" => iri,
      "orderedItems" => collection,
      "next" => "#{iri}?max_id=#{min_id}"
    }

    if max_qid == nil do
      %{
        "id" => iri,
        "type" => "OrderedCollection",
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
      "orderedItems" => collection,
      "next" => "#{iri}?max_id=#{min_id}"
    }

    if max_qid == nil do
      %{
        "id" => iri,
        "type" => "OrderedCollection",
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

  defp maybe_make_image(func, key, user) do
    if image = func.(user, no_default: true) do
      %{
        key => %{
          "type" => "Image",
          "url" => image
        }
      }
    else
      %{}
    end
  end
end
