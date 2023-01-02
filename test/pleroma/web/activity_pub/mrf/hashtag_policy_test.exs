# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.HashtagPolicyTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "it sets the sensitive property with relevant hashtags" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "#nsfw hey"})
    {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

    assert modified["object"]["sensitive"]
  end

  test "it is history-aware" do
    activity = %{
      "type" => "Create",
      "object" => %{
        "content" => "hey",
        "tag" => []
      }
    }

    activity_data =
      activity
      |> put_in(
        ["object", "formerRepresentations"],
        %{
          "type" => "OrderedCollection",
          "orderedItems" => [
            Map.put(
              activity["object"],
              "tag",
              [%{"type" => "Hashtag", "name" => "#nsfw"}]
            )
          ]
        }
      )

    {:ok, modified} =
      Pleroma.Web.ActivityPub.MRF.filter_one(
        Pleroma.Web.ActivityPub.MRF.HashtagPolicy,
        activity_data
      )

    refute modified["object"]["sensitive"]
    assert Enum.at(modified["object"]["formerRepresentations"]["orderedItems"], 0)["sensitive"]
  end

  test "it works with Update" do
    activity = %{
      "type" => "Update",
      "object" => %{
        "content" => "hey",
        "tag" => []
      }
    }

    activity_data =
      activity
      |> put_in(
        ["object", "formerRepresentations"],
        %{
          "type" => "OrderedCollection",
          "orderedItems" => [
            Map.put(
              activity["object"],
              "tag",
              [%{"type" => "Hashtag", "name" => "#nsfw"}]
            )
          ]
        }
      )

    {:ok, modified} =
      Pleroma.Web.ActivityPub.MRF.filter_one(
        Pleroma.Web.ActivityPub.MRF.HashtagPolicy,
        activity_data
      )

    refute modified["object"]["sensitive"]
    assert Enum.at(modified["object"]["formerRepresentations"]["orderedItems"], 0)["sensitive"]
  end

  test "it doesn't sets the sensitive property with irrelevant hashtags" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "#cofe hey"})
    {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

    refute modified["object"]["sensitive"]
  end
end
