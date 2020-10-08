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
      user = insert(:user, discoverable: false)

      assert Pleroma.Web.Metadata.build_tags(%{user: user}) =~
               "<meta content=\"noindex, noarchive\" name=\"robots\">"
    end

    test "for local user set to discoverable" do
      user = insert(:user, discoverable: true)

      refute Pleroma.Web.Metadata.build_tags(%{user: user}) =~
               "<meta content=\"noindex, noarchive\" name=\"robots\">"
    end
  end

  describe "no metadata for private instances" do
    test "for local user set to discoverable" do
      clear_config([:instance, :public], false)
      user = insert(:user, bio: "This is my secret fedi account bio", discoverable: true)

      assert "" = Pleroma.Web.Metadata.build_tags(%{user: user})
    end

    test "search exclusion metadata is included" do
      clear_config([:instance, :public], false)
      user = insert(:user, bio: "This is my secret fedi account bio", discoverable: false)

      assert ~s(<meta content="noindex, noarchive" name="robots">) ==
               Pleroma.Web.Metadata.build_tags(%{user: user})
    end
  end
end
