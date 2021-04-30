# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.SafeJsonbSetTest do
  use Pleroma.DataCase, async: true

  test "it doesn't wipe the object when asked to set the value to NULL" do
    assert %{rows: [[%{"key" => "value", "test" => nil}]]} =
             Ecto.Adapters.SQL.query!(
               Pleroma.Repo,
               "select safe_jsonb_set('{\"key\": \"value\"}'::jsonb, '{test}', NULL);",
               []
             )
  end
end
