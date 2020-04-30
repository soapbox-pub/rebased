# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.DeleteHandlingTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Pleroma.Factory
  import ExUnit.CaptureLog

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "it works for incoming deletes" do
    activity = insert(:note_activity)
    deleting_user = insert(:user)

    data =
      File.read!("test/fixtures/mastodon-delete.json")
      |> Poison.decode!()

    object =
      data["object"]
      |> Map.put("id", activity.data["object"])

    data =
      data
      |> Map.put("object", object)
      |> Map.put("actor", deleting_user.ap_id)

    {:ok, %Activity{actor: actor, local: false, data: %{"id" => id}}} =
      Transmogrifier.handle_incoming(data)

    assert id == data["id"]

    # We delete the Create activity because base our timelines on it.
    # This should be changed after we unify objects and activities
    refute Activity.get_by_id(activity.id)
    assert actor == deleting_user.ap_id

    # Objects are replaced by a tombstone object.
    object = Object.normalize(activity.data["object"])
    assert object.data["type"] == "Tombstone"
  end

  test "it fails for incoming deletes with spoofed origin" do
    activity = insert(:note_activity)

    data =
      File.read!("test/fixtures/mastodon-delete.json")
      |> Poison.decode!()

    object =
      data["object"]
      |> Map.put("id", activity.data["object"])

    data =
      data
      |> Map.put("object", object)

    assert capture_log(fn ->
             :error = Transmogrifier.handle_incoming(data)
           end) =~
             "[error] Could not decode user at fetch http://mastodon.example.org/users/gargron, {:error, :nxdomain}"

    assert Activity.get_by_id(activity.id)
  end

  @tag capture_log: true
  test "it works for incoming user deletes" do
    %{ap_id: ap_id} = insert(:user, ap_id: "http://mastodon.example.org/users/admin")

    data =
      File.read!("test/fixtures/mastodon-delete-user.json")
      |> Poison.decode!()

    {:ok, _} = Transmogrifier.handle_incoming(data)
    ObanHelpers.perform_all()

    refute User.get_cached_by_ap_id(ap_id)
  end

  test "it fails for incoming user deletes with spoofed origin" do
    %{ap_id: ap_id} = insert(:user)

    data =
      File.read!("test/fixtures/mastodon-delete-user.json")
      |> Poison.decode!()
      |> Map.put("actor", ap_id)

    assert capture_log(fn ->
             assert :error == Transmogrifier.handle_incoming(data)
           end) =~ "Object containment failed"

    assert User.get_cached_by_ap_id(ap_id)
  end
end
