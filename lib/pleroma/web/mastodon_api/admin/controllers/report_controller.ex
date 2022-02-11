# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.Admin.ReportController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [
      add_link_headers: 2,
      json_response: 3
    ]

  alias Pleroma.Activity
  alias Pleroma.Pagination
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.AdminAPI.Report
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(OAuthScopesPlug, %{scopes: ["admin:read:reports"]} when action in [:index, :show])

  plug(OAuthScopesPlug, %{scopes: ["admin:write:reports"]} when action in [:resolve, :reopen])

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.MastodonAdmin.ReportOperation

  def index(conn, params) do
    opts =
      %{}
      |> Map.put(:type, "Flag")
      |> Map.put(:skip_preload, true)
      |> Map.put(:preload_report_notes, true)
      |> Map.put(:total, true)
      |> restrict_state(params)
      |> restrict_actor(params)

    # |> restrict_target(params)

    reports =
      ActivityPub.fetch_activities_query([], opts)
      |> Pagination.fetch_paginated(params)

    conn
    |> add_link_headers(reports)
    |> render("index.json", reports: reports)
  end

  def show(conn, %{id: id}) do
    with %Activity{} = report <- Activity.get_report(id) do
      render(conn, "show.json", Report.extract_report_info(report))
    else
      _ -> {:error, :not_found}
    end
  end

  def resolve(conn, %{id: id}) do
    with {:ok, report} <- CommonAPI.update_report_state(id, "resolved") do
      render(conn, "show.json", Report.extract_report_info(report))
    else
      {:error, error} ->
        json_response(conn, :bad_request, %{error: error})
    end
  end

  def reopen(conn, %{id: id}) do
    with {:ok, report} <- CommonAPI.update_report_state(id, "open") do
      render(conn, "show.json", Report.extract_report_info(report))
    else
      {:error, error} ->
        json_response(conn, :bad_request, %{error: error})
    end
  end

  defp restrict_state(opts, %{resolved: true}), do: Map.put(opts, :state, "resolved")

  defp restrict_state(opts, %{resolved: false}), do: Map.put(opts, :state, "open")

  defp restrict_state(opts, _params), do: opts

  defp restrict_actor(opts, %{account_id: actor}) do
    with %User{ap_id: ap_id} <- User.get_by_id(actor) do
      Map.put(opts, :actor_id, ap_id)
    else
      _ -> Map.put(opts, :actor_id, actor)
    end
  end

  defp restrict_actor(opts, _params), do: opts

  # defp restrict_target(opts, %{target_account_id: target}) do
  #   with %User{id: id} <- User.get_by_ap_id(target) do
  #     Map.put(opts, :user_actor_id, id)
  #   else
  #     _ -> Map.put(opts, :user_actor_id, target)
  #   end
  # end

  # defp restrict_target(opts, _params), do: opts
end
