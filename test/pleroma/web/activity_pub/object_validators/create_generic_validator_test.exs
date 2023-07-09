# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.CreateGenericValidatorTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.CreateGenericValidator
  alias Pleroma.Web.ActivityPub.Utils

  import Pleroma.Factory

  test "a Create/Note from Roadhouse validates" do
    insert(:user, ap_id: "https://macgirvin.com/channel/mike")

    note_activity =
      "test/fixtures/roadhouse-create-activity.json"
      |> File.read!()
      |> Jason.decode!()

    # Build metadata
    {:ok, object_data} = ObjectValidator.cast_and_apply(note_activity["object"])
    meta = [object_data: ObjectValidator.stringify_keys(object_data)]

    assert %{valid?: true} = CreateGenericValidator.cast_and_validate(note_activity, meta)
  end

  test "a Create/Note with mismatched context uses the Note's context" do
    user = insert(:user)

    note = %{
      "id" => Utils.generate_object_id(),
      "type" => "Note",
      "actor" => user.ap_id,
      "to" => [user.follower_address],
      "cc" => [],
      "content" => "Hello world",
      "context" => Utils.generate_context_id()
    }

    note_activity = %{
      "id" => Utils.generate_activity_id(),
      "type" => "Create",
      "actor" => note["actor"],
      "to" => note["to"],
      "cc" => note["cc"],
      "object" => note,
      "published" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "context" => Utils.generate_context_id()
    }

    # Build metadata
    {:ok, object_data} = ObjectValidator.cast_and_apply(note_activity["object"])
    meta = [object_data: ObjectValidator.stringify_keys(object_data)]

    validated = CreateGenericValidator.cast_and_validate(note_activity, meta)

    assert validated.valid?
    assert {:context, note["context"]} in validated.changes
  end
end
