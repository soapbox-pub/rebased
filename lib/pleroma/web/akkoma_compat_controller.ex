# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AkkomaCompatController do
  use Pleroma.Web, :controller

  alias Pleroma.Activity
  alias Pleroma.Language.Translation
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(:skip_auth when action == :translation_languages)

  plug(
    OAuthScopesPlug,
    %{fallback: :proceed_unauthenticated, scopes: ["read:statuses"]} when action == :translate
  )

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.AkkomaCompatOperation

  @doc "GET /api/v1/akkoma/translation/languages"
  def translation_languages(conn, _params) do
    with {:enabled, true} <- {:enabled, Translation.configured?()},
         {:ok, source_languages} <- Translation.supported_languages(:source),
         {:ok, target_languages} <- Translation.supported_languages(:target) do
      source_languages =
        source_languages
        |> Enum.map(fn lang -> %{code: lang, name: lang} end)

      target_languages =
        target_languages
        |> Enum.map(fn lang -> %{code: lang, name: lang} end)

      conn
      |> json(%{source: source_languages, target: target_languages})
    else
      {:enabled, false} ->
        json(conn, %{})

      e ->
        {:error, e}
    end
  end

  @doc "GET /api/v1/statuses/:id/translations/:language"
  def translate(
        %{
          assigns: %{user: user},
          private: %{open_api_spex: %{params: %{id: status_id} = params}}
        } = conn,
        _
      ) do
    with {:authentication, true} <-
           {:authentication,
            !is_nil(user) ||
              Pleroma.Config.get([Translation, :allow_unauthenticated])},
         %Activity{object: object} <- Activity.get_by_id_with_object(status_id),
         {:visibility, visibility} when visibility in ["public", "unlisted"] <-
           {:visibility, Visibility.get_visibility(object)},
         {:allow_remote, true} <-
           {:allow_remote,
            Object.local?(object) ||
              Pleroma.Config.get([Translation, :allow_remote])},
         {:language, language} when is_binary(language) <-
           {:language, Map.get(params, :language) || user.language},
         {:ok, result} <-
           Translation.translate(
             object.data["content"],
             object.data["language"],
             language
           ) do
      json(conn, %{detected_language: result.detected_source_language, text: result.content})
    else
      {:authentication, false} ->
        render_error(conn, :unauthorized, "Authorization is required to translate statuses")

      {:allow_remote, false} ->
        render_error(conn, :bad_request, "You can't translate remote posts")

      {:language, nil} ->
        render_error(conn, :bad_request, "Language not specified")

      {:visibility, _} ->
        render_error(conn, :not_found, "Record not found")

      {:error, :not_found} ->
        render_error(conn, :not_found, "Translation service not configured")

      {:error, error} when error in [:unexpected_response, :quota_exceeded, :too_many_requests] ->
        render_error(conn, :service_unavailable, "Translation service not available")

      nil ->
        render_error(conn, :not_found, "Record not found")
    end
  end
end
