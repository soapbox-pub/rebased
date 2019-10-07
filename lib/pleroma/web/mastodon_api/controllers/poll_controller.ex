# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.PollController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [try_render: 3, json_response: 3]

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:statuses"], fallback: :proceed_unauthenticated} when action == :show
  )

  plug(OAuthScopesPlug, %{scopes: ["write:statuses"]} when action == :vote)

  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)

  @doc "GET /api/v1/polls/:id"
  def show(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Object{} = object <- Object.get_by_id_and_maybe_refetch(id, interval: 60),
         %Activity{} = activity <- Activity.get_create_by_object_ap_id(object.data["id"]),
         true <- Visibility.visible_for_user?(activity, user) do
      try_render(conn, "show.json", %{object: object, for: user})
    else
      error when is_nil(error) or error == false ->
        render_error(conn, :not_found, "Record not found")
    end
  end

  @doc "POST /api/v1/polls/:id/votes"
  def vote(%{assigns: %{user: user}} = conn, %{"id" => id, "choices" => choices}) do
    with %Object{data: %{"type" => "Question"}} = object <- Object.get_by_id(id),
         %Activity{} = activity <- Activity.get_create_by_object_ap_id(object.data["id"]),
         true <- Visibility.visible_for_user?(activity, user),
         {:ok, _activities, object} <- get_cached_vote_or_vote(user, object, choices) do
      try_render(conn, "show.json", %{object: object, for: user})
    else
      nil -> render_error(conn, :not_found, "Record not found")
      false -> render_error(conn, :not_found, "Record not found")
      {:error, message} -> json_response(conn, :unprocessable_entity, %{error: message})
    end
  end

  defp get_cached_vote_or_vote(user, object, choices) do
    idempotency_key = "polls:#{user.id}:#{object.data["id"]}"

    Cachex.fetch!(:idempotency_cache, idempotency_key, fn ->
      case CommonAPI.vote(user, object, choices) do
        {:error, _message} = res -> {:ignore, res}
        res -> {:commit, res}
      end
    end)
  end
end
