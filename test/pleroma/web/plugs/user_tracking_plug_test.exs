# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.UserTrackingPlugTest do
  use Pleroma.Web.ConnCase, async: true

  import Pleroma.Factory

  alias Pleroma.Web.Plugs.UserTrackingPlug

  test "updates last_active_at for a new user", %{conn: conn} do
    user = insert(:user)

    assert is_nil(user.last_active_at)

    test_started_at = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    %{assigns: %{user: user}} =
      conn
      |> assign(:user, user)
      |> UserTrackingPlug.call(%{})

    assert user.last_active_at >= test_started_at
    assert user.last_active_at <= NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
  end

  test "doesn't update last_active_at if it was updated recently", %{conn: conn} do
    last_active_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-:timer.hours(1), :millisecond)
      |> NaiveDateTime.truncate(:second)

    user = insert(:user, %{last_active_at: last_active_at})

    %{assigns: %{user: user}} =
      conn
      |> assign(:user, user)
      |> UserTrackingPlug.call(%{})

    assert user.last_active_at == last_active_at
  end

  test "skips updating last_active_at if user ID is nil", %{conn: conn} do
    %{assigns: %{user: user}} =
      conn
      |> assign(:user, %Pleroma.User{})
      |> UserTrackingPlug.call(%{})

    assert is_nil(user.last_active_at)
  end

  test "does nothing if user is not present", %{conn: conn} do
    %{assigns: assigns} = UserTrackingPlug.call(conn, %{})

    refute Map.has_key?(assigns, :user)
  end
end
