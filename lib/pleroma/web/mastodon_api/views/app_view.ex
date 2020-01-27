# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AppView do
  use Pleroma.Web, :view

  alias Pleroma.Web.OAuth.App

  def render("show.json", %{app: %App{} = app}) do
    %{
      id: app.id |> to_string,
      name: app.client_name,
      client_id: app.client_id,
      client_secret: app.client_secret,
      redirect_uri: app.redirect_uris,
      website: app.website
    }
    |> with_vapid_key()
  end

  def render("short.json", %{app: %App{website: webiste, client_name: name}}) do
    %{
      name: name,
      website: webiste
    }
    |> with_vapid_key()
  end

  defp with_vapid_key(data) do
    vapid_key = Application.get_env(:web_push_encryption, :vapid_details, [])[:public_key]

    if vapid_key do
      Map.put(data, "vapid_key", vapid_key)
    else
      data
    end
  end
end
