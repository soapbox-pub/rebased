# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MetadataTest do
  use Pleroma.DataCase, async: true

  import Pleroma.Factory

  describe "restrict indexing remote users" do
    test "for remote user" do
      user = insert(:user, local: false)

      assert Pleroma.Web.Metadata.build_tags(%{user: user}) =~
               "<meta content=\"noindex, noarchive\" name=\"robots\">"
    end

    test "for local user" do
      user = insert(:user)

      refute Pleroma.Web.Metadata.build_tags(%{user: user}) =~
               "<meta content=\"noindex, noarchive\" name=\"robots\">"
    end
  end
end
