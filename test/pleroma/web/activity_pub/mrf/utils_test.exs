# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.UtilsTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.MRF.Utils

  describe "describe_regex_or_string/1" do
    test "describes regex" do
      assert "~r/foo/i" == Utils.describe_regex_or_string(~r/foo/i)
    end

    test "returns string as-is" do
      assert "foo" == Utils.describe_regex_or_string("foo")
    end
  end
end
