# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
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

  plug(Pleroma.Web.ApiSpec.CastAndValidate, replace_params: false)
  defdelegate open_api_operation(action), to: ApiSpec.UserImportOperation

  def follow(
        %{private: %{open_api_spex: %{body_params: %{list: %Plug.Upload{path: path}}}}} = conn,
        _
      ) do
    list = File.read!(path)
    do_follow(conn, list)
  end

  def follow(%{private: %{open_api_spex: %{body_params: %{list: list}}}} = conn, _),
    do: do_follow(conn, list)

  def do_follow(%{assigns: %{user: follower}} = conn, list) do
    identifiers =
      list
      |> String.split("\n")
      |> Enum.map(&(&1 |> String.split(",") |> List.first()))
      |> List.delete("Account address")
      |> Enum.map(&(&1 |> String.trim() |> String.trim_leading("@")))
      |> Enum.reject(&(&1 == ""))

    User.Import.follows_import(follower, identifiers)
    json(conn, "jobs started")
  end

  def blocks(
        %{private: %{open_api_spex: %{body_params: %{list: %Plug.Upload{path: path}}}}} = conn,
        _
      ) do
    list = File.read!(path)
    do_block(conn, list)
  end

  def blocks(%{private: %{open_api_spex: %{body_params: %{list: list}}}} = conn, _),
    do: do_block(conn, list)

  defp do_block(%{assigns: %{user: blocker}} = conn, list) do
    User.Import.blocks_import(blocker, prepare_user_identifiers(list))
    json(conn, "jobs started")
  end

  def mutes(
        %{private: %{open_api_spex: %{body_params: %{list: %Plug.Upload{path: path}}}}} = conn,
        _
      ) do
    list = File.read!(path)
    do_mute(conn, list)
  end

  def mutes(%{private: %{open_api_spex: %{body_params: %{list: list}}}} = conn, _),
    do: do_mute(conn, list)

  defp do_mute(%{assigns: %{user: user}} = conn, list) do
    User.Import.mutes_import(user, prepare_user_identifiers(list))
    json(conn, "jobs started")
  end

  defp prepare_user_identifiers(list) do
    list
    |> String.split()
    |> Enum.map(&String.trim_leading(&1, "@"))
  end
end
