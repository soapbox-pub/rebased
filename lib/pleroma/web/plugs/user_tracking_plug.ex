# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.UserTrackingPlug do
  alias Pleroma.User

  import Plug.Conn, only: [assign: 3]

  @update_interval :timer.hours(24)

  def init(opts), do: opts

  def call(%{assigns: %{user: %User{id: id} = user}} = conn, _) when not is_nil(id) do
    with true <- needs_update?(user),
         {:ok, user} <- User.update_last_active_at(user) do
      assign(conn, :user, user)
    else
      _ -> conn
    end
  end

  def call(conn, _), do: conn

  defp needs_update?(%User{last_active_at: nil}), do: true

  defp needs_update?(%User{last_active_at: last_active_at}) do
    NaiveDateTime.diff(NaiveDateTime.utc_now(), last_active_at, :millisecond) >= @update_interval
  end
end
