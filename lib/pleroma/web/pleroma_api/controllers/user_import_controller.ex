# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.UserImportController do
  use Pleroma.Web, :controller

  require Logger

  alias Pleroma.User
  alias Pleroma.Web.ApiSpec
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(OAuthScopesPlug, %{scopes: ["follow", "write:follows"]} when action == :follow)
  plug(OAuthScopesPlug, %{scopes: ["follow", "write:blocks"]} when action == :blocks)
  plug(OAuthScopesPlug, %{scopes: ["follow", "write:mutes"]} when action == :mutes)

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  defdelegate open_api_operation(action), to: ApiSpec.UserImportOperation

  def follow(%{body_params: %{list: %Plug.Upload{path: path}}} = conn, _) do
    follow(%Plug.Conn{conn | body_params: %{list: File.read!(path)}}, %{})
  end

  def follow(%{assigns: %{user: follower}, body_params: %{list: list}} = conn, _) do
    identifiers =
      list
      |> String.split("\n")
      |> Enum.map(&(&1 |> String.split(",") |> List.first()))
      |> List.delete("Account address")
      |> Enum.map(&(&1 |> String.trim() |> String.trim_leading("@")))
      |> Enum.reject(&(&1 == ""))

    User.Import.follow_import(follower, identifiers)
    json(conn, "job started")
  end

  def blocks(%{body_params: %{list: %Plug.Upload{path: path}}} = conn, _) do
    blocks(%Plug.Conn{conn | body_params: %{list: File.read!(path)}}, %{})
  end

  def blocks(%{assigns: %{user: blocker}, body_params: %{list: list}} = conn, _) do
    User.Import.blocks_import(blocker, prepare_user_identifiers(list))
    json(conn, "job started")
  end

  def mutes(%{body_params: %{list: %Plug.Upload{path: path}}} = conn, _) do
    mutes(%Plug.Conn{conn | body_params: %{list: File.read!(path)}}, %{})
  end

  def mutes(%{assigns: %{user: user}, body_params: %{list: list}} = conn, _) do
    User.Import.mutes_import(user, prepare_user_identifiers(list))
    json(conn, "job started")
  end

  defp prepare_user_identifiers(list) do
    list
    |> String.split()
    |> Enum.map(&String.trim_leading(&1, "@"))
  end
end
