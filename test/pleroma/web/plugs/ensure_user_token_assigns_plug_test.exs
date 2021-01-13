# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.EnsureUserTokenAssignsPlugTest do
  use Pleroma.Web.ConnCase, async: true

  import Pleroma.Factory

  alias Pleroma.Web.Plugs.EnsureUserTokenAssignsPlug

  test "with :user assign set to a User record " <>
         "and :token assign set to a Token belonging to this user, " <>
         "it does nothing" do
    %{conn: conn} = oauth_access(["read"])

    ret_conn = EnsureUserTokenAssignsPlug.call(conn, %{})

    assert conn == ret_conn
  end

  test "with :user assign set to a User record " <>
         "but :token assign not set or not a Token, " <>
         "it assigns :token to `nil`",
       %{conn: conn} do
    user = insert(:user)
    conn = assign(conn, :user, user)

    ret_conn = EnsureUserTokenAssignsPlug.call(conn, %{})

    assert %{token: nil} = ret_conn.assigns

    ret_conn2 =
      conn
      |> assign(:token, 1)
      |> EnsureUserTokenAssignsPlug.call(%{})

    assert %{token: nil} = ret_conn2.assigns
  end

  # Abnormal (unexpected) scenario
  test "with :user assign set to a User record " <>
         "but :token assign set to a Token NOT belonging to :user, " <>
         "it drops auth info" do
    %{conn: conn} = oauth_access(["read"])
    other_user = insert(:user)

    conn = assign(conn, :user, other_user)

    ret_conn = EnsureUserTokenAssignsPlug.call(conn, %{})

    assert %{user: nil, token: nil} = ret_conn.assigns
  end

  test "if :user assign is not set to a User record, it sets :user and :token to nil", %{
    conn: conn
  } do
    ret_conn = EnsureUserTokenAssignsPlug.call(conn, %{})

    assert %{user: nil, token: nil} = ret_conn.assigns

    ret_conn2 =
      conn
      |> assign(:user, 1)
      |> EnsureUserTokenAssignsPlug.call(%{})

    assert %{user: nil, token: nil} = ret_conn2.assigns
  end
end
