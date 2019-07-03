# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SearchController do
  use Pleroma.Web, :controller
  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.StatusView

  alias Pleroma.Web.ControllerHelper

  require Logger

  plug(Pleroma.Plugs.RateLimiter, :search when action in [:search, :search2, :account_search])

  def search2(%{assigns: %{user: user}} = conn, %{"q" => query} = params) do
    accounts = with_fallback(fn -> User.search(query, search_options(params, user)) end, [])
    statuses = with_fallback(fn -> Activity.search(user, query) end, [])
    tags_path = Web.base_url() <> "/tag/"

    tags =
      query
      |> String.split()
      |> Enum.uniq()
      |> Enum.filter(fn tag -> String.starts_with?(tag, "#") end)
      |> Enum.map(fn tag -> String.slice(tag, 1..-1) end)
      |> Enum.map(fn tag -> %{name: tag, url: tags_path <> tag} end)

    res = %{
      "accounts" => AccountView.render("accounts.json", users: accounts, for: user, as: :user),
      "statuses" =>
        StatusView.render("index.json", activities: statuses, for: user, as: :activity),
      "hashtags" => tags
    }

    json(conn, res)
  end

  def search(%{assigns: %{user: user}} = conn, %{"q" => query} = params) do
    accounts = with_fallback(fn -> User.search(query, search_options(params, user)) end, [])
    statuses = with_fallback(fn -> Activity.search(user, query) end, [])

    tags =
      query
      |> String.split()
      |> Enum.uniq()
      |> Enum.filter(fn tag -> String.starts_with?(tag, "#") end)
      |> Enum.map(fn tag -> String.slice(tag, 1..-1) end)

    res = %{
      "accounts" => AccountView.render("accounts.json", users: accounts, for: user, as: :user),
      "statuses" =>
        StatusView.render("index.json", activities: statuses, for: user, as: :activity),
      "hashtags" => tags
    }

    json(conn, res)
  end

  def account_search(%{assigns: %{user: user}} = conn, %{"q" => query} = params) do
    accounts = User.search(query, search_options(params, user))
    res = AccountView.render("accounts.json", users: accounts, for: user, as: :user)

    json(conn, res)
  end

  defp search_options(params, user) do
    [
      resolve: params["resolve"] == "true",
      following: params["following"] == "true",
      limit: ControllerHelper.fetch_integer_param(params, "limit"),
      offset: ControllerHelper.fetch_integer_param(params, "offset"),
      for_user: user
    ]
  end

  defp with_fallback(f, fallback) do
    try do
      f.()
    rescue
      error ->
        Logger.error("#{__MODULE__} search error: #{inspect(error)}")
        fallback
    end
  end
end
