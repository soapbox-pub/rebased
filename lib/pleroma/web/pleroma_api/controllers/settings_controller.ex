# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.SettingsController do
  use Pleroma.Web, :controller

  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:accounts"]} when action in [:update]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:accounts"]} when action in [:show]
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaSettingsOperation

  @doc "GET /api/v1/pleroma/settings/:app"
  def show(%{assigns: %{user: user}} = conn, %{app: app} = _params) do
    conn
    |> json(get_settings(user, app))
  end

  @doc "PATCH /api/v1/pleroma/settings/:app"
  def update(%{assigns: %{user: user}, body_params: body_params} = conn, %{app: app} = _params) do
    settings =
      get_settings(user, app)
      |> merge_recursively(body_params)

    with changeset <-
           Pleroma.User.update_changeset(
             user,
             %{pleroma_settings_store: %{app => settings}}
           ),
         {:ok, _} <- Pleroma.Repo.update(changeset) do
      conn
      |> json(settings)
    end
  end

  defp merge_recursively(old, %{} = new) do
    old = ensure_object(old)

    Enum.reduce(
      new,
      old,
      fn
        {k, nil}, acc ->
          Map.drop(acc, [k])

        {k, %{} = new_child}, acc ->
          Map.put(acc, k, merge_recursively(acc[k], new_child))

        {k, v}, acc ->
          Map.put(acc, k, v)
      end
    )
  end

  defp get_settings(user, app) do
    user.pleroma_settings_store
    |> Map.get(app, %{})
    |> ensure_object()
  end

  defp ensure_object(%{} = object) do
    object
  end

  defp ensure_object(_) do
    %{}
  end
end
