# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.TokenView do
  use Pleroma.Web, :view

  def render("index.json", %{tokens: tokens}) do
    tokens
    |> render_many(Pleroma.Web.TwitterAPI.TokenView, "show.json")
    |> Enum.filter(&Enum.any?/1)
  end

  def render("show.json", %{token: token_entry}) do
    %{
      id: token_entry.id,
      token: token_entry.token,
      refresh_token: token_entry.refresh_token,
      valid_until: token_entry.valid_until
    }
  end
end
