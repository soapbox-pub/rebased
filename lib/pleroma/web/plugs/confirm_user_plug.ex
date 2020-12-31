# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.ConfirmUserPlug do
  @moduledoc """
  If a user has ever been granted an OAuth token, they are eligible to become
  confirmed, regardless of the account_activation_required setting. This plug
  will confirm a user if found.
  """

  alias Pleroma.User
  import Plug.Conn

  def init(opts), do: opts

  def call(%{assigns: %{user: %User{confirmation_pending: true} = user}} = conn, _opts) do
    with {:ok, user} <- confirm_user(user) do
      assign(conn, :user, user)
    end
  end

  def call(conn, _opts), do: conn

  defp confirm_user(%User{} = user) do
    user
    |> User.confirmation_changeset(need_confirmation: false)
    |> User.update_and_set_cache()
  end
end
