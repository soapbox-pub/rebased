# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.PublisherMigrationChangeTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase
  import Pleroma.Factory
  import Pleroma.Tests.Helpers

  alias Pleroma.Activity
  alias Pleroma.Workers.PublisherWorker

  setup_all do: require_migration("20240729163838_publisher_job_change")

  describe "up/0" do
    test "migrates publisher jobs to new format", %{migration: migration} do
      user = insert(:user)

      %Activity{id: activity_id, data: %{"id" => ap_id}} =
        insert(:note_activity, user: user)

      {:ok, %{id: job_id}} =
        PublisherWorker.new(%{
          "actor_id" => user.id,
          "json" => "{}",
          "id" => ap_id,
          "inbox" => "https://example.com/inbox",
          "unreachable_since" => nil
        })
        |> Oban.insert()

      assert [%{id: ^job_id, args: %{"id" => ^ap_id}}] = all_enqueued(worker: PublisherWorker)

      assert migration.up() == :ok

      assert_enqueued(
        worker: PublisherWorker,
        args: %{"id" => ap_id, "activity_id" => activity_id}
      )
    end
  end
end
