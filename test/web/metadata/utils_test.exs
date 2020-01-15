# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.UtilsTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Web.Metadata.Utils

  describe "scrub_html_and_truncate/1" do
    test "it returns text without encode HTML" do
      user = insert(:user)

      note =
        insert(:note, %{
          data: %{
            "actor" => user.ap_id,
            "id" => "https://pleroma.gov/objects/whatever",
            "content" => "Pleroma's really cool!"
          }
        })

      assert Utils.scrub_html_and_truncate(note) == "Pleroma's really cool!"
    end
  end

  describe "scrub_html_and_truncate/2" do
    test "it returns text without encode HTML" do
      assert Utils.scrub_html_and_truncate("Pleroma's really cool!") == "Pleroma's really cool!"
    end
  end
end
