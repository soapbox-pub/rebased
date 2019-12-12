# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.Scopes do
  @moduledoc """
  Functions for dealing with scopes.
  """

  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.User

  @doc """
  Fetch scopes from request params.

  Note: `scopes` is used by Mastodon — supporting it but sticking to
  OAuth's standard `scope` wherever we control it
  """
  @spec fetch_scopes(map(), list()) :: list()
  def fetch_scopes(params, default) do
    parse_scopes(params["scope"] || params["scopes"], default)
  end

  def parse_scopes(scopes, _default) when is_list(scopes) do
    Enum.filter(scopes, &(&1 not in [nil, ""]))
  end

  def parse_scopes(scopes, default) when is_binary(scopes) do
    scopes
    |> to_list
    |> parse_scopes(default)
  end

  def parse_scopes(_, default) do
    default
  end

  @doc """
  Convert scopes string to list
  """
  @spec to_list(binary()) :: [binary()]
  def to_list(nil), do: []

  def to_list(str) do
    str
    |> String.trim()
    |> String.split(~r/[\s,]+/)
  end

  @doc """
  Convert scopes list to string
  """
  @spec to_string(list()) :: binary()
  def to_string(scopes), do: Enum.join(scopes, " ")

  @doc """
  Validates scopes.
  """
  @spec validate(list() | nil, list(), User.t()) ::
          {:ok, list()} | {:error, :missing_scopes | :unsupported_scopes}
  def validate(blank_scopes, _app_scopes, _user) when blank_scopes in [nil, []],
    do: {:error, :missing_scopes}

  def validate(scopes, app_scopes, %User{} = user) do
    with {:ok, _} <- ensure_scopes_support(scopes, app_scopes),
         {:ok, scopes} <- authorize_admin_scopes(scopes, app_scopes, user) do
      {:ok, scopes}
    end
  end

  defp ensure_scopes_support(scopes, app_scopes) do
    case OAuthScopesPlug.filter_descendants(scopes, app_scopes) do
      ^scopes -> {:ok, scopes}
      _ -> {:error, :unsupported_scopes}
    end
  end

  defp authorize_admin_scopes(scopes, app_scopes, %User{} = user) do
    if user.is_admin || !contains_admin_scopes?(scopes) || !contains_admin_scopes?(app_scopes) do
      {:ok, scopes}
    else
      # Gracefully dropping admin scopes from requested scopes if user isn't an admin (not raising)
      scopes = scopes -- OAuthScopesPlug.filter_descendants(scopes, ["admin"])
      validate(scopes, app_scopes, user)
    end
  end

  def contains_admin_scopes?(scopes) do
    scopes
    |> OAuthScopesPlug.filter_descendants(["admin"])
    |> Enum.any?()
  end
end
