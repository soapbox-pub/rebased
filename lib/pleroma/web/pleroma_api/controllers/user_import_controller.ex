# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.UserImportController do
  use Pleroma.Web, :controller

  require Logger

  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.User

  plug(OAuthScopesPlug, %{scopes: ["follow", "write:follows"]} when action == :follow)
  plug(OAuthScopesPlug, %{scopes: ["follow", "write:blocks"]} when action == :blocks)
  plug(OAuthScopesPlug, %{scopes: ["follow", "write:mutes"]} when action == :mutes)

  def follow(conn, %{"list" => %Plug.Upload{path: path}}) do
    follow(conn, %{"list" => File.read!(path)})
  end

  def follow(%{assigns: %{user: follower}} = conn, %{"list" => list}) do
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

  def blocks(conn, %{"list" => %Plug.Upload{path: path}}) do
    blocks(conn, %{"list" => File.read!(path)})
  end

  def blocks(%{assigns: %{user: blocker}} = conn, %{"list" => list}) do
    User.Import.blocks_import(blocker, prepare_user_identifiers(list))
    json(conn, "job started")
  end

  def mutes(conn, %{"list" => %Plug.Upload{path: path}}) do
    mutes(conn, %{"list" => File.read!(path)})
  end

  def mutes(%{assigns: %{user: user}} = conn, %{"list" => list}) do
    User.Import.mutes_import(user, prepare_user_identifiers(list))
    json(conn, "job started")
  end

  defp prepare_user_identifiers(list) do
    list
    |> String.split()
    |> Enum.map(&String.trim_leading(&1, "@"))
  end
end
