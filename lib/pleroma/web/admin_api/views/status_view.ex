# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.StatusView do
  use Pleroma.Web, :view

  require Pleroma.Constants

  alias Pleroma.Web.AdminAPI
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI

  defdelegate merge_account_views(user), to: AdminAPI.AccountView

  def render("index.json", %{total: total} = opts) do
    %{total: total, activities: safe_render_many(opts.activities, __MODULE__, "show.json", opts)}
  end

  def render("index.json", opts) do
    safe_render_many(opts.activities, __MODULE__, "show.json", opts)
  end

  def render("show.json", %{activity: %{data: %{"object" => _object}} = activity} = opts) do
    user = CommonAPI.get_user(activity.data["actor"])

    MastodonAPI.StatusView.render("show.json", opts)
    |> Map.merge(%{account: merge_account_views(user)})
  end
end
