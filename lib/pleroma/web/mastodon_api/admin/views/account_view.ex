# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.Admin.AccountView do
  use Pleroma.Web, :view

  alias Pleroma.User
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI

  def render("index.json", %{users: users}) do
    render_many(users, __MODULE__, "show.json", as: :user)
  end

  def render("show.json", %{user: user}) do
    account =
      MastodonAPI.AccountView.render("show.json", %{user: user, skip_visibility_check: true})

    %{
      id: user.id,
      username: username_from_nickname(user.nickname),
      domain: domain_from_nickname(user.nickname),
      created_at: Utils.to_masto_date(user.inserted_at),
      email: user.email,
      ip: nil,
      role: role(user),
      confirmed: user.is_confirmed,
      sensitized: nil,
      suspened: nil,
      silenced: nil,
      disabled: !user.is_active,
      approved: user.is_approved,
      locale: nil,
      invite_request: user.registration_reason,
      ips: nil,
      account: account
    }
  end

  defp username_from_nickname(string) when is_binary(string) do
    hd(String.split(string, "@"))
  end

  defp username_from_nickname(_), do: nil

  defp domain_from_nickname(string) when is_binary(string) do
    String.split(string, "@")
    |> Enum.at(1, nil)
  end

  defp domain_from_nickname(_), do: nil

  defp role(%User{is_admin: true}) do
    "admin"
  end

  defp role(%User{is_moderator: true}) do
    "moderator"
  end

  defp role(_user) do
    nil
  end
end
