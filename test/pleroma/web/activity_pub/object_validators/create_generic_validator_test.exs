# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.CreateGenericValidatorTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.CreateGenericValidator

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

    %{valid?: true} = CreateGenericValidator.cast_and_validate(note_activity, meta)
  end
end
