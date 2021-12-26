# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SuggestionView do
  use Pleroma.Web, :view
  alias Pleroma.Web.MastodonAPI.AccountView

  @source_types [:staff, :global, :past_interactions]

  def render("index.json", %{users: users} = opts) do
    Enum.map(users, fn user ->
      opts =
        opts
        |> Map.put(:user, user)
        |> Map.delete(:users)

      render("show.json", opts)
    end)
  end

  def render("show.json", %{source: source, user: _user} = opts) when source in @source_types do
    %{
      source: source,
      account: AccountView.render("show.json", opts)
    }
  end
end
