# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Preload.Providers.UserTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory
  alias Pleroma.Web.Preload.Providers.User

  describe "returns empty when user doesn't exist" do
    test "nil user specified" do
      assert User.generate_terms(%{user: nil}) == %{}
    end

    test "missing user specified" do
      assert User.generate_terms(%{user: :not_a_user}) == %{}
    end
  end

  describe "specified user exists" do
    setup do
      user = insert(:user)

      terms = User.generate_terms(%{user: user})
      %{terms: terms, user: user}
    end

    test "account is rendered", %{terms: terms, user: user} do
      account = terms["/api/v1/accounts/#{user.id}"]
      assert %{acct: user, username: user} = account
    end
  end
end
