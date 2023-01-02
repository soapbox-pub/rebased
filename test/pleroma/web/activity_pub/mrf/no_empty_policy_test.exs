# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NoEmptyPolicyTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.MRF.NoEmptyPolicy

  setup_all do: clear_config([:mrf, :policies], [Pleroma.Web.ActivityPub.MRF.NoEmptyPolicy])

  test "Notes with content are exempt" do
    message = %{
      "actor" => "http://localhost:4001/users/testuser",
      "cc" => ["http://localhost:4001/users/testuser/followers"],
      "object" => %{
        "actor" => "http://localhost:4001/users/testuser",
        "attachment" => [],
        "cc" => ["http://localhost:4001/users/testuser/followers"],
        "source" => "this is a test post",
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "type" => "Note"
      },
      "to" => ["https://www.w3.org/ns/activitystreams#Public"],
      "type" => "Create"
    }

    assert NoEmptyPolicy.filter(message) == {:ok, message}
  end

  test "Polls are exempt" do
    message = %{
      "actor" => "http://localhost:4001/users/testuser",
      "cc" => ["http://localhost:4001/users/testuser/followers"],
      "object" => %{
        "actor" => "http://localhost:4001/users/testuser",
        "attachment" => [],
        "cc" => ["http://localhost:4001/users/testuser/followers"],
        "oneOf" => [
          %{
            "name" => "chocolate",
            "replies" => %{"totalItems" => 0, "type" => "Collection"},
            "type" => "Note"
          },
          %{
            "name" => "vanilla",
            "replies" => %{"totalItems" => 0, "type" => "Collection"},
            "type" => "Note"
          }
        ],
        "source" => "@user2",
        "to" => [
          "https://www.w3.org/ns/activitystreams#Public",
          "http://localhost:4001/users/user2"
        ],
        "type" => "Question"
      },
      "to" => [
        "https://www.w3.org/ns/activitystreams#Public",
        "http://localhost:4001/users/user2"
      ],
      "type" => "Create"
    }

    assert NoEmptyPolicy.filter(message) == {:ok, message}
  end

  test "Notes with attachments are exempt" do
    message = %{
      "actor" => "http://localhost:4001/users/testuser",
      "cc" => ["http://localhost:4001/users/testuser/followers"],
      "object" => %{
        "actor" => "http://localhost:4001/users/testuser",
        "attachment" => [
          %{
            "actor" => "http://localhost:4001/users/testuser",
            "mediaType" => "image/png",
            "name" => "",
            "type" => "Document",
            "url" => [
              %{
                "href" =>
                  "http://localhost:4001/media/68ba231cf12e1382ce458f1979969f8ed5cc07ba198a02e653464abaf39bdb90.png",
                "mediaType" => "image/png",
                "type" => "Link"
              }
            ]
          }
        ],
        "cc" => ["http://localhost:4001/users/testuser/followers"],
        "source" => "@user2",
        "to" => [
          "https://www.w3.org/ns/activitystreams#Public",
          "http://localhost:4001/users/user2"
        ],
        "type" => "Note"
      },
      "to" => [
        "https://www.w3.org/ns/activitystreams#Public",
        "http://localhost:4001/users/user2"
      ],
      "type" => "Create"
    }

    assert NoEmptyPolicy.filter(message) == {:ok, message}
  end

  test "Notes with only mentions are denied" do
    message = %{
      "actor" => "http://localhost:4001/users/testuser",
      "cc" => ["http://localhost:4001/users/testuser/followers"],
      "object" => %{
        "actor" => "http://localhost:4001/users/testuser",
        "attachment" => [],
        "cc" => ["http://localhost:4001/users/testuser/followers"],
        "source" => "@user2",
        "to" => [
          "https://www.w3.org/ns/activitystreams#Public",
          "http://localhost:4001/users/user2"
        ],
        "type" => "Note"
      },
      "to" => [
        "https://www.w3.org/ns/activitystreams#Public",
        "http://localhost:4001/users/user2"
      ],
      "type" => "Create"
    }

    assert NoEmptyPolicy.filter(message) == {:reject, "[NoEmptyPolicy]"}
  end

  test "Notes with no content are denied" do
    message = %{
      "actor" => "http://localhost:4001/users/testuser",
      "cc" => ["http://localhost:4001/users/testuser/followers"],
      "object" => %{
        "actor" => "http://localhost:4001/users/testuser",
        "attachment" => [],
        "cc" => ["http://localhost:4001/users/testuser/followers"],
        "source" => "",
        "to" => [
          "https://www.w3.org/ns/activitystreams#Public"
        ],
        "type" => "Note"
      },
      "to" => [
        "https://www.w3.org/ns/activitystreams#Public"
      ],
      "type" => "Create"
    }

    assert NoEmptyPolicy.filter(message) == {:reject, "[NoEmptyPolicy]"}
  end

  test "works with Update" do
    message = %{
      "actor" => "http://localhost:4001/users/testuser",
      "cc" => ["http://localhost:4001/users/testuser/followers"],
      "object" => %{
        "actor" => "http://localhost:4001/users/testuser",
        "attachment" => [],
        "cc" => ["http://localhost:4001/users/testuser/followers"],
        "source" => "",
        "to" => [
          "https://www.w3.org/ns/activitystreams#Public"
        ],
        "type" => "Note"
      },
      "to" => [
        "https://www.w3.org/ns/activitystreams#Public"
      ],
      "type" => "Update"
    }

    assert NoEmptyPolicy.filter(message) == {:reject, "[NoEmptyPolicy]"}
  end
end
