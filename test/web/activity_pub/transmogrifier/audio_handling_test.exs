# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.AudioHandlingTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Pleroma.Factory

  test "it works for incoming listens" do
    _user = insert(:user, ap_id: "http://mastodon.example.org/users/admin")

    data = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "to" => ["https://www.w3.org/ns/activitystreams#Public"],
      "cc" => [],
      "type" => "Listen",
      "id" => "http://mastodon.example.org/users/admin/listens/1234/activity",
      "actor" => "http://mastodon.example.org/users/admin",
      "object" => %{
        "type" => "Audio",
        "id" => "http://mastodon.example.org/users/admin/listens/1234",
        "attributedTo" => "http://mastodon.example.org/users/admin",
        "title" => "lain radio episode 1",
        "artist" => "lain",
        "album" => "lain radio",
        "length" => 180_000
      }
    }

    {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(data)

    object = Object.normalize(activity)

    assert object.data["title"] == "lain radio episode 1"
    assert object.data["artist"] == "lain"
    assert object.data["album"] == "lain radio"
    assert object.data["length"] == 180_000
  end
end
