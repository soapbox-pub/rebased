# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.AddRemoveHandlingTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase, async: true

  require Pleroma.Constants

  import Pleroma.Factory

  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier

  test "it accepts Add/Remove activities" do
    user =
      "test/fixtures/users_mock/user.json"
      |> File.read!()
      |> String.replace("{{nickname}}", "lain")

    object_id = "c61d6733-e256-4fe1-ab13-1e369789423f"

    object =
      "test/fixtures/statuses/note.json"
      |> File.read!()
      |> String.replace("{{nickname}}", "lain")
      |> String.replace("{{object_id}}", object_id)

    object_url = "https://example.com/objects/#{object_id}"

    actor = "https://example.com/users/lain"

    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: ^actor
      } ->
        %Tesla.Env{
          status: 200,
          body: user,
          headers: [{"content-type", "application/activity+json"}]
        }

      %{
        method: :get,
        url: ^object_url
      } ->
        %Tesla.Env{
          status: 200,
          body: object,
          headers: [{"content-type", "application/activity+json"}]
        }

      %{method: :get, url: "https://example.com/users/lain/collections/featured"} ->
        %Tesla.Env{
          status: 200,
          body:
            "test/fixtures/users_mock/masto_featured.json"
            |> File.read!()
            |> String.replace("{{domain}}", "example.com")
            |> String.replace("{{nickname}}", "lain"),
          headers: [{"content-type", "application/activity+json"}]
        }
    end)

    message = %{
      "id" => "https://example.com/objects/d61d6733-e256-4fe1-ab13-1e369789423f",
      "actor" => actor,
      "object" => object_url,
      "target" => "https://example.com/users/lain/collections/featured",
      "type" => "Add",
      "to" => [Pleroma.Constants.as_public()],
      "cc" => ["https://example.com/users/lain/followers"],
      "bcc" => [],
      "bto" => []
    }

    assert {:ok, activity} = Transmogrifier.handle_incoming(message)
    assert activity.data == message
    user = User.get_cached_by_ap_id(actor)
    assert user.pinned_objects[object_url]

    remove = %{
      "id" => "http://localhost:400/objects/d61d6733-e256-4fe1-ab13-1e369789423d",
      "actor" => actor,
      "object" => object_url,
      "target" => "https://example.com/users/lain/collections/featured",
      "type" => "Remove",
      "to" => [Pleroma.Constants.as_public()],
      "cc" => ["https://example.com/users/lain/followers"],
      "bcc" => [],
      "bto" => []
    }

    assert {:ok, activity} = Transmogrifier.handle_incoming(remove)
    assert activity.data == remove

    user = refresh_record(user)
    refute user.pinned_objects[object_url]
  end

  test "Add/Remove activities for remote users without featured address" do
    user = insert(:user, local: false, domain: "example.com")

    user =
      user
      |> Ecto.Changeset.change(featured_address: nil)
      |> Repo.update!()

    %{host: host} = URI.parse(user.ap_id)

    user_data =
      "test/fixtures/users_mock/user.json"
      |> File.read!()
      |> String.replace("{{nickname}}", user.nickname)

    object_id = "c61d6733-e256-4fe1-ab13-1e369789423f"

    object =
      "test/fixtures/statuses/note.json"
      |> File.read!()
      |> String.replace("{{nickname}}", user.nickname)
      |> String.replace("{{object_id}}", object_id)

    object_url = "https://#{host}/objects/#{object_id}"

    actor = "https://#{host}/users/#{user.nickname}"

    featured = "https://#{host}/users/#{user.nickname}/collections/featured"

    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: ^actor
      } ->
        %Tesla.Env{
          status: 200,
          body: user_data,
          headers: [{"content-type", "application/activity+json"}]
        }

      %{
        method: :get,
        url: ^object_url
      } ->
        %Tesla.Env{
          status: 200,
          body: object,
          headers: [{"content-type", "application/activity+json"}]
        }

      %{method: :get, url: ^featured} ->
        %Tesla.Env{
          status: 200,
          body:
            "test/fixtures/users_mock/masto_featured.json"
            |> File.read!()
            |> String.replace("{{domain}}", "#{host}")
            |> String.replace("{{nickname}}", user.nickname),
          headers: [{"content-type", "application/activity+json"}]
        }
    end)

    message = %{
      "id" => "https://#{host}/objects/d61d6733-e256-4fe1-ab13-1e369789423f",
      "actor" => actor,
      "object" => object_url,
      "target" => "https://#{host}/users/#{user.nickname}/collections/featured",
      "type" => "Add",
      "to" => [Pleroma.Constants.as_public()],
      "cc" => ["https://#{host}/users/#{user.nickname}/followers"],
      "bcc" => [],
      "bto" => []
    }

    assert {:ok, activity} = Transmogrifier.handle_incoming(message)
    assert activity.data == message
    user = User.get_cached_by_ap_id(actor)
    assert user.pinned_objects[object_url]
  end
end
