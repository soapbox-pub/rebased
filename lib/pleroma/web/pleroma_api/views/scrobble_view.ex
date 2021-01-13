# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ScrobbleView do
  use Pleroma.Web, :view

  require Pleroma.Constants

  alias Pleroma.Activity
  alias Pleroma.HTML
  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.AccountView

  def render("show.json", %{activity: %Activity{data: %{"type" => "Listen"}} = activity} = opts) do
    object = Object.normalize(activity, fetch: false)

    user = CommonAPI.get_user(activity.data["actor"])
    created_at = Utils.to_masto_date(activity.data["published"])

    %{
      id: activity.id,
      account: AccountView.render("show.json", %{user: user, for: opts[:for]}),
      created_at: created_at,
      title: object.data["title"] |> HTML.strip_tags(),
      artist: object.data["artist"] |> HTML.strip_tags(),
      album: object.data["album"] |> HTML.strip_tags(),
      length: object.data["length"]
    }
  end

  def render("index.json", opts) do
    safe_render_many(opts.activities, __MODULE__, "show.json", opts)
  end
end
