# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.Token.Strategy.RefreshToken do
  @moduledoc """
  Functions for dealing with refresh token strategy.
  """

  alias Pleroma.Config
  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.OAuth.Token.Strategy.Revoke

  @doc """
  Will grant access token by refresh token.
  """
  @spec grant(Token.t()) :: {:ok, Token.t()} | {:error, any()}
  def grant(token) do
    access_token = Repo.preload(token, [:user, :app])

    result =
      Repo.transaction(fn ->
        token_params = %{
          app: access_token.app,
          user: access_token.user,
          scopes: access_token.scopes
        }

        access_token
        |> revoke_access_token()
        |> create_access_token(token_params)
      end)

    case result do
      {:ok, {:error, reason}} -> {:error, reason}
      {:ok, {:ok, token}} -> {:ok, token}
      {:error, reason} -> {:error, reason}
    end
  end

  defp revoke_access_token(token) do
    Revoke.revoke(token)
  end

  defp create_access_token({:error, error}, _), do: {:error, error}

  defp create_access_token({:ok, token}, %{app: app, user: user} = token_params) do
    Token.create_token(app, user, add_refresh_token(token_params, token.refresh_token))
  end

  defp add_refresh_token(params, token) do
    case Config.get([:oauth2, :issue_new_refresh_token], false) do
      true -> Map.put(params, :refresh_token, token)
      false -> params
    end
  end
end
