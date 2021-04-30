# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.UserUpdateHandlingTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Pleroma.Factory

  test "it works for incoming update activities" do
    user = insert(:user, local: false)

    update_data = File.read!("test/fixtures/mastodon-update.json") |> Jason.decode!()

    object =
      update_data["object"]
      |> Map.put("actor", user.ap_id)
      |> Map.put("id", user.ap_id)

    update_data =
      update_data
      |> Map.put("actor", user.ap_id)
      |> Map.put("object", object)

    {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(update_data)

    assert data["id"] == update_data["id"]

    user = User.get_cached_by_ap_id(data["actor"])
    assert user.name == "gargle"

    assert user.avatar["url"] == [
             %{
               "href" =>
                 "https://cd.niu.moe/accounts/avatars/000/033/323/original/fd7f8ae0b3ffedc9.jpeg"
             }
           ]

    assert user.banner["url"] == [
             %{
               "href" =>
                 "https://cd.niu.moe/accounts/headers/000/033/323/original/850b3448fa5fd477.png"
             }
           ]

    assert user.bio == "<p>Some bio</p>"
  end

  test "it works with alsoKnownAs" do
    %{ap_id: actor} = insert(:user, local: false)

    assert User.get_cached_by_ap_id(actor).also_known_as == []

    {:ok, _activity} =
      "test/fixtures/mastodon-update.json"
      |> File.read!()
      |> Jason.decode!()
      |> Map.put("actor", actor)
      |> Map.update!("object", fn object ->
        object
        |> Map.put("actor", actor)
        |> Map.put("id", actor)
        |> Map.put("alsoKnownAs", [
          "http://mastodon.example.org/users/foo",
          "http://example.org/users/bar"
        ])
      end)
      |> Transmogrifier.handle_incoming()

    assert User.get_cached_by_ap_id(actor).also_known_as == [
             "http://mastodon.example.org/users/foo",
             "http://example.org/users/bar"
           ]
  end

  test "it works with custom profile fields" do
    user = insert(:user, local: false)

    assert user.fields == []

    update_data = File.read!("test/fixtures/mastodon-update.json") |> Jason.decode!()

    object =
      update_data["object"]
      |> Map.put("actor", user.ap_id)
      |> Map.put("id", user.ap_id)

    update_data =
      update_data
      |> Map.put("actor", user.ap_id)
      |> Map.put("object", object)

    {:ok, _update_activity} = Transmogrifier.handle_incoming(update_data)

    user = User.get_cached_by_ap_id(user.ap_id)

    assert user.fields == [
             %{"name" => "foo", "value" => "updated"},
             %{"name" => "foo1", "value" => "updated"}
           ]

    clear_config([:instance, :max_remote_account_fields], 2)

    update_data =
      update_data
      |> put_in(["object", "attachment"], [
        %{"name" => "foo", "type" => "PropertyValue", "value" => "bar"},
        %{"name" => "foo11", "type" => "PropertyValue", "value" => "bar11"},
        %{"name" => "foo22", "type" => "PropertyValue", "value" => "bar22"}
      ])
      |> Map.put("id", update_data["id"] <> ".")

    {:ok, _} = Transmogrifier.handle_incoming(update_data)

    user = User.get_cached_by_ap_id(user.ap_id)

    assert user.fields == [
             %{"name" => "foo", "value" => "updated"},
             %{"name" => "foo1", "value" => "updated"}
           ]

    update_data =
      update_data
      |> put_in(["object", "attachment"], [])
      |> Map.put("id", update_data["id"] <> ".")

    {:ok, _} = Transmogrifier.handle_incoming(update_data)

    user = User.get_cached_by_ap_id(user.ap_id)

    assert user.fields == []
  end

  test "it works for incoming update activities which lock the account" do
    user = insert(:user, local: false)

    update_data = File.read!("test/fixtures/mastodon-update.json") |> Jason.decode!()

    object =
      update_data["object"]
      |> Map.put("actor", user.ap_id)
      |> Map.put("id", user.ap_id)
      |> Map.put("manuallyApprovesFollowers", true)

    update_data =
      update_data
      |> Map.put("actor", user.ap_id)
      |> Map.put("object", object)

    {:ok, %Activity{local: false}} = Transmogrifier.handle_incoming(update_data)

    user = User.get_cached_by_ap_id(user.ap_id)
    assert user.is_locked == true
  end
end
