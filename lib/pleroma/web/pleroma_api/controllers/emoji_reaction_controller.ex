# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EmojiReactionController do
  use Pleroma.Web, :controller

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(OAuthScopesPlug, %{scopes: ["write:statuses"]} when action in [:create, :delete])

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:statuses"], fallback: :proceed_unauthenticated}
    when action == :index
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.EmojiReactionOperation

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  def index(%{assigns: %{user: user}} = conn, %{id: activity_id} = params) do
    with true <- Pleroma.Config.get([:instance, :show_reactions]),
         %Activity{} = activity <- Activity.get_by_id_with_object(activity_id),
         %Object{data: %{"reactions" => reactions}} when is_list(reactions) <-
           Object.normalize(activity, fetch: false) do
      reactions =
        reactions
        |> filter(params)
        |> filter_allowed_users(user, Map.get(params, :with_muted, false))

      render(conn, "index.json", emoji_reactions: reactions, user: user)
    else
      _e -> json(conn, [])
    end
  end

  def filter_allowed_users(reactions, user, with_muted) do
    exclude_ap_ids =
      if is_nil(user) do
        []
      else
        User.cached_blocked_users_ap_ids(user) ++
          if not with_muted, do: User.cached_muted_users_ap_ids(user), else: []
      end

    filter_emoji = fn emoji, users ->
      case Enum.reject(users, &(&1 in exclude_ap_ids)) do
        [] -> nil
        users -> {emoji, users}
      end
    end

    reactions
    |> Stream.map(fn
      [emoji, users] when is_list(users) -> filter_emoji.(emoji, users)
      {emoji, users} when is_list(users) -> filter_emoji.(emoji, users)
      _ -> nil
    end)
    |> Stream.reject(&is_nil/1)
  end

  defp filter(reactions, %{emoji: emoji}) when is_binary(emoji) do
    Enum.filter(reactions, fn [e, _] -> e == emoji end)
  end

  defp filter(reactions, _), do: reactions

  def create(%{assigns: %{user: user}} = conn, %{id: activity_id, emoji: emoji}) do
    with {:ok, _activity} <- CommonAPI.react_with_emoji(activity_id, user, emoji) do
      activity = Activity.get_by_id(activity_id)

      conn
      |> put_view(StatusView)
      |> render("show.json", activity: activity, for: user, as: :activity)
    end
  end

  def delete(%{assigns: %{user: user}} = conn, %{id: activity_id, emoji: emoji}) do
    with {:ok, _activity} <- CommonAPI.unreact_with_emoji(activity_id, user, emoji) do
      activity = Activity.get_by_id(activity_id)

      conn
      |> put_view(StatusView)
      |> render("show.json", activity: activity, for: user, as: :activity)
    end
  end
end
