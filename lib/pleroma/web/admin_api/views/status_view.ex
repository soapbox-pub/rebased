# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.StatusView do
  use Pleroma.Web, :view

  require Pleroma.Constants

  alias Pleroma.User

  def render("index.json", opts) do
    safe_render_many(opts.activities, __MODULE__, "show.json", opts)
  end

  def render("show.json", %{activity: %{data: %{"object" => _object}} = activity} = opts) do
    user = get_user(activity.data["actor"])

    Pleroma.Web.MastodonAPI.StatusView.render("show.json", opts)
    |> Map.merge(%{account: merge_account_views(user)})
  end

  defp merge_account_views(%User{} = user) do
    Pleroma.Web.MastodonAPI.AccountView.render("show.json", %{user: user})
    |> Map.merge(Pleroma.Web.AdminAPI.AccountView.render("show.json", %{user: user}))
  end

  defp merge_account_views(_), do: %{}

  defp get_user(ap_id) do
    cond do
      user = User.get_cached_by_ap_id(ap_id) ->
        user

      user = User.get_by_guessed_nickname(ap_id) ->
        user

      true ->
        User.error_user(ap_id)
    end
  end
end
