# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.Admin.AccountController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [
      add_link_headers: 2,
      assign_account_by_id: 2,
      json_response: 3
    ]

  alias Pleroma.Activity
  alias Pleroma.ModerationLog
  alias Pleroma.Pagination
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.Pipeline
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  @filter_params ~W(
    local external active needing_approval deactivated nickname name email staff
  )

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:read:accounts"]}
    when action in [:index, :show]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:write:accounts"]}
    when action in [
           :delete,
           :enable,
           :account_action,
           :approve,
           :reject
         ]
  )

  plug(
    :assign_account_by_id
    when action in [
           :show,
           :delete,
           :enable,
           :account_action,
           :approve,
           :reject
         ]
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.MastodonAdmin.AccountOperation

  def index(conn, params) do
    users =
      params
      |> build_criteria()
      |> User.Query.build()
      |> Pagination.fetch_paginated(params)

    conn
    |> add_link_headers(users)
    |> render("index.json", users: users)
  end

  def show(%{assigns: %{user: _admin, account: user}} = conn, _params) do
    render(conn, "show.json", user: user)
  end

  def account_action(
        %{assigns: %{user: admin, account: user}, body_params: %{type: type} = body_params} =
          conn,
        _params
      ) do
    {:ok, _user} = handle_account_action(user, admin, type)

    resolve_report(admin, body_params)

    json_response(conn, :no_content, "")
  end

  def delete(%{assigns: %{user: admin, account: user}} = conn, _params) do
    {:ok, delete_data, _} = Builder.delete(admin, user.ap_id)
    Pipeline.common_pipeline(delete_data, local: true)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: [user],
      action: "delete"
    })

    render(conn, "show.json", user: user)
  end

  def enable(%{assigns: %{user: admin, account: user}} = conn, _params) do
    {:ok, user} = User.set_activation(user, true)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: [user],
      action: "activate"
    })

    render(conn, "show.json", user: user)
  end

  def approve(%{assigns: %{user: admin, account: user}} = conn, _params) do
    {:ok, user} = User.approve(user)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: [user],
      action: "approve"
    })

    render(conn, "show.json", user: user)
  end

  def reject(%{assigns: %{user: admin, account: user}} = conn, _params) do
    with {:ok, _} <- User.reject(user) do
      ModerationLog.insert_log(%{
        actor: admin,
        subject: [user],
        action: "reject"
      })

      render(conn, "show.json", user: user)
    else
      {:error, error} ->
        json_response(conn, :bad_request, %{error: error})
    end
  end

  defp handle_account_action(%User{local: true} = user, admin, "disable") do
    ModerationLog.insert_log(%{
      actor: admin,
      subject: [user],
      action: "deactivate"
    })

    User.set_activation(user, false)
  end

  defp handle_account_action(user, _admin, _type) do
    {:ok, user}
  end

  defp build_criteria(params) do
    %{}
    |> maybe_filter_local(params)
    |> maybe_filter_external(params)
    |> maybe_filter_active(params)
    |> maybe_filter_needing_approval(params)
    |> maybe_filter_deactivated(params)
    |> maybe_filter_nickname(params)
    |> maybe_filter_name(params)
    |> maybe_filter_email(params)
    |> maybe_filter_staff(params)
  end

  defp maybe_filter_local(criteria, %{local: true} = _params),
    do: Map.put(criteria, :local, true)

  defp maybe_filter_local(criteria, %{local: false} = _params),
    do: Map.put(criteria, :external, true)

  defp maybe_filter_external(criteria, %{remote: true} = _params),
    do: Map.put(criteria, :external, true)

  defp maybe_filter_external(criteria, %{remote: false} = _params),
    do: Map.put(criteria, :local, true)

  defp maybe_filter_active(criteria, %{active: active} = _params),
    do: Map.put(criteria, :active, active)

  defp maybe_filter_needing_approval(criteria, %{pending: need_approval} = _params),
    do: Map.put(criteria, :need_approval, need_approval)

  defp maybe_filter_deactivated(criteria, %{disabled: deactivated} = _params),
    do: Map.put(criteria, :deactivated, deactivated)

  defp maybe_filter_nickname(criteria, %{username: nickname} = _params),
    do: Map.put(criteria, :nickname, nickname)

  defp maybe_filter_name(criteria, %{display_name: name} = _params),
    do: Map.put(criteria, :name, name)

  defp maybe_filter_email(criteria, %{email: email} = _params),
    do: Map.put(criteria, :email, email)

  defp maybe_filter_staff(criteria, %{staff: staff} = _params),
    do: Map.put(criteria, :staff, staff)

  for filter_param <- @filter_params do
    defp unquote(:"maybe_filter_#{filter_param}")(criteria, _params), do: criteria
  end

  defp resolve_report(admin, %{report_id: id}) do
    with {:ok, activity} <- CommonAPI.update_report_state(id, "resolved"),
         report <- Activity.get_by_id_with_user_actor(activity.id) do
      ModerationLog.insert_log(%{
        action: "report_update",
        actor: admin,
        subject: activity,
        subject_actor: report.user_actor
      })
    end
  end

  defp resolve_report(_admin, _params) do
  end
end
