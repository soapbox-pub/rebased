# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.PollController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [try_render: 3, json_response: 3]

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Workers.PollWorker

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(Pleroma.Web.ApiSpec.CastAndValidate, replace_params: false)

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:statuses"], fallback: :proceed_unauthenticated} when action == :show
  )

  plug(OAuthScopesPlug, %{scopes: ["write:statuses"]} when action == :vote)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PollOperation

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)
  @poll_refresh_interval 120

  @doc "GET /api/v1/polls/:id"
  def show(%{assigns: %{user: user}, private: %{open_api_spex: %{params: %{id: id}}}} = conn, _) do
    with %Object{} = object <- Object.get_by_id(id),
         %Activity{} = activity <-
           Activity.get_create_by_object_ap_id_with_object(object.data["id"]),
         true <- Visibility.visible_for_user?(activity, user) do
      maybe_refresh_poll(activity)

      try_render(conn, "show.json", %{object: object, for: user})
    else
      error when is_nil(error) or error == false ->
        render_error(conn, :not_found, "Record not found")
    end
  end

  @doc "POST /api/v1/polls/:id/votes"
  def vote(
        %{
          assigns: %{user: user},
          private: %{open_api_spex: %{body_params: %{choices: choices}, params: %{id: id}}}
        } = conn,
        _
      ) do
    with %Object{data: %{"type" => "Question"}} = object <- Object.get_by_id(id),
         %Activity{} = activity <- Activity.get_create_by_object_ap_id(object.data["id"]),
         true <- Visibility.visible_for_user?(activity, user),
         {:ok, _activities, object} <- get_cached_vote_or_vote(object, user, choices) do
      try_render(conn, "show.json", %{object: object, for: user})
    else
      nil -> render_error(conn, :not_found, "Record not found")
      false -> render_error(conn, :not_found, "Record not found")
      {:error, message} -> json_response(conn, :unprocessable_entity, %{error: message})
    end
  end

  defp get_cached_vote_or_vote(object, user, choices) do
    idempotency_key = "polls:#{user.id}:#{object.data["id"]}"

    @cachex.fetch!(:idempotency_cache, idempotency_key, fn _ ->
      case CommonAPI.vote(object, user, choices) do
        {:error, _message} = res -> {:ignore, res}
        res -> {:commit, res}
      end
    end)
  end

  defp maybe_refresh_poll(%Activity{object: %Object{} = object} = activity) do
    with false <- activity.local,
         {:ok, end_time} <- NaiveDateTime.from_iso8601(object.data["closed"]),
         {_, :lt} <- {:closed_compare, NaiveDateTime.compare(object.updated_at, end_time)} do
      PollWorker.new(%{"op" => "refresh", "activity_id" => activity.id})
      |> Oban.insert(unique: [period: @poll_refresh_interval])
    end
  end
end
