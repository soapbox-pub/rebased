# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Preload.Providers.User do
  alias Pleroma.User
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.Preload.Providers.Provider

  @behaviour Provider
  @account_url_base "/api/v1/accounts"

  @impl Provider
  def generate_terms(%{user: user}) do
    build_accounts_tag(%{}, user)
  end

  def generate_terms(_params), do: %{}

  def build_accounts_tag(acc, %User{} = user) do
    account_data = AccountView.render("show.json", %{user: user, for: user})
    Map.put(acc, "#{@account_url_base}/#{user.id}", account_data)
  end

  def build_accounts_tag(acc, _), do: acc
end
