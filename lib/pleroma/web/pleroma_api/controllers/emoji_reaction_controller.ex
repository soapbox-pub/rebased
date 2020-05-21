# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EmojiReactionController do
  use Pleroma.Web, :controller

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.StatusView

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(OAuthScopesPlug, %{scopes: ["write:statuses"]} when action in [:create, :delete])

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:statuses"], fallback: :proceed_unauthenticated}
    when action == :index
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.EmojiReactionOperation

  def index(%{assigns: %{user: user}} = conn, %{id: activity_id} = params) do
    with %Activity{} = activity <- Activity.get_by_id_with_object(activity_id),
         %Object{data: %{"reactions" => reactions}} when is_list(reactions) <-
           Object.normalize(activity) do
      reactions = filter(reactions, params)
      render(conn, "index.json", emoji_reactions: reactions, user: user)
    else
      _e -> json(conn, [])
    end
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
