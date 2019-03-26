# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AppView do
  use Pleroma.Web, :view

  alias Pleroma.Web.OAuth.App

  def render("show.json", %{app: %App{website: webiste, client_name: name}}) do
    result = %{
      name: name,
      website: webiste
    }

    vapid_key = Pleroma.Web.Push.vapid_config() |> Keyword.get(:public_key)

    result =
      if vapid_key do
        Map.put(result, "vapid_key", vapid_key)
      else
        result
      end

    result
  end
end
