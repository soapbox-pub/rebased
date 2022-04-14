# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HashtagTest do
  use Pleroma.DataCase

  alias Pleroma.Hashtag

  describe "changeset validations" do
    test "ensure non-blank :name" do
      changeset = Hashtag.changeset(%Hashtag{}, %{name: ""})

      assert {:name, {"can't be blank", [validation: :required]}} in changeset.errors
    end
  end
end
