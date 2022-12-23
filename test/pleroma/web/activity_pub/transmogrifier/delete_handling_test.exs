# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
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

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "it works for incoming deletes" do
    activity = insert(:note_activity)
    deleting_user = insert(:user)

    data =
      File.read!("test/fixtures/mastodon-delete.json")
      |> Jason.decode!()
      |> Map.put("actor", deleting_user.ap_id)
      |> put_in(["object", "id"], activity.data["object"])

    {:ok, %Activity{actor: actor, local: false, data: %{"id" => id}}} =
      Transmogrifier.handle_incoming(data)

    assert id == data["id"]

    # We delete the Create activity because we base our timelines on it.
    # This should be changed after we unify objects and activities
    refute Activity.get_by_id(activity.id)
    assert actor == deleting_user.ap_id

    # Objects are replaced by a tombstone object.
    object = Object.normalize(activity.data["object"], fetch: false)
    assert object.data["type"] == "Tombstone"
  end

  test "it works for incoming when the object has been pruned" do
    activity = insert(:note_activity)

    {:ok, object} =
      Object.normalize(activity.data["object"], fetch: false)
      |> Repo.delete()

    # TODO: mock cachex
    Cachex.del(:object_cache, "object:#{object.data["id"]}")

    deleting_user = insert(:user)

    data =
      File.read!("test/fixtures/mastodon-delete.json")
      |> Jason.decode!()
      |> Map.put("actor", deleting_user.ap_id)
      |> put_in(["object", "id"], activity.data["object"])

    {:ok, %Activity{actor: actor, local: false, data: %{"id" => id}}} =
      Transmogrifier.handle_incoming(data)

    assert id == data["id"]

    # We delete the Create activity because we base our timelines on it.
    # This should be changed after we unify objects and activities
    refute Activity.get_by_id(activity.id)
    assert actor == deleting_user.ap_id
  end

  test "it fails for incoming deletes with spoofed origin" do
    activity = insert(:note_activity)
    %{ap_id: ap_id} = insert(:user, ap_id: "https://gensokyo.2hu/users/raymoo")

    data =
      File.read!("test/fixtures/mastodon-delete.json")
      |> Jason.decode!()
      |> Map.put("actor", ap_id)
      |> put_in(["object", "id"], activity.data["object"])

    assert match?({:error, _}, Transmogrifier.handle_incoming(data))
  end

  @tag capture_log: true
  test "it works for incoming user deletes" do
    %{ap_id: ap_id} = insert(:user, ap_id: "http://mastodon.example.org/users/admin")

    data =
      File.read!("test/fixtures/mastodon-delete-user.json")
      |> Jason.decode!()

    {:ok, _} = Transmogrifier.handle_incoming(data)
    ObanHelpers.perform_all()

    refute User.get_cached_by_ap_id(ap_id).is_active
  end

  test "it fails for incoming user deletes with spoofed origin" do
    %{ap_id: ap_id} = insert(:user)

    data =
      File.read!("test/fixtures/mastodon-delete-user.json")
      |> Jason.decode!()
      |> Map.put("actor", ap_id)

    assert match?({:error, _}, Transmogrifier.handle_incoming(data))

    assert User.get_cached_by_ap_id(ap_id)
  end
end
