# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.StatusView do
  use Pleroma.Web, :view

  require Pleroma.Constants

  alias Pleroma.User
  alias Pleroma.Web.AdminAPI
  alias Pleroma.Web.MastodonAPI
  alias Pleroma.Web.MastodonAPI.StatusView

  def render("index.json", opts) do
    safe_render_many(opts.activities, __MODULE__, "show.json", opts)
  end

  def render("show.json", %{activity: %{data: %{"object" => _object}} = activity} = opts) do
    user = StatusView.get_user(activity.data["actor"])

    StatusView.render("show.json", opts)
    |> Map.merge(%{account: merge_account_views(user)})
  end

  defp merge_account_views(%User{} = user) do
    MastodonAPI.AccountView.render("show.json", %{user: user, skip_relationships: true})
    |> Map.merge(AdminAPI.AccountView.render("show.json", %{user: user}))
  end

  defp merge_account_views(_), do: %{}
end
