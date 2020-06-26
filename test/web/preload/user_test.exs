# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Preload.Providers.UserTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Web.Preload.Providers.User

  describe "returns empty when user doesn't exist" do
    test "nil user specified" do
      refute User.generate_terms(%{user: nil})
             |> Map.has_key?("/api/v1/accounts")
    end

    test "missing user specified" do
      refute User.generate_terms(%{user: :not_a_user})
             |> Map.has_key?("/api/v1/accounts")
    end
  end

  describe "specified user exists" do
    setup do
      user = insert(:user)

      {:ok, User.generate_terms(%{user: user})}
    end

    test "account is rendered", %{"/api/v1/accounts": accounts} do
      assert %{acct: user, username: user} = accounts
    end
  end
end
