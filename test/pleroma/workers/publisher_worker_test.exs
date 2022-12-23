# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PublisherWorkerTest do
  use Pleroma.DataCase, async: true
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Federator

  describe "Oban job priority:" do
    setup do
      user = insert(:user)

      {:ok, post} = CommonAPI.post(user, %{status: "Regrettable post"})
      object = Object.normalize(post, fetch: false)
      {:ok, delete_data, _meta} = Builder.delete(user, object.data["id"])
      {:ok, delete, _meta} = ActivityPub.persist(delete_data, local: true)

      %{
        post: post,
        delete: delete
      }
    end

    test "Deletions are lower priority", %{delete: delete} do
      assert {:ok, %Oban.Job{priority: 3}} = Federator.publish(delete)
    end

    test "Creates are normal priority", %{post: post} do
      assert {:ok, %Oban.Job{priority: 0}} = Federator.publish(post)
    end
  end
end
