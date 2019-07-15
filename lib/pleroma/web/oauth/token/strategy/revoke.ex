# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.Token.Strategy.Revoke do
  @moduledoc """
  Functions for dealing with revocation.
  """

  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Token

  @doc "Finds and revokes access token for app and by token"
  @spec revoke(App.t(), map()) :: {:ok, Token.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def revoke(%App{} = app, %{"token" => token} = _attrs) do
    with {:ok, token} <- Token.get_by_token(app, token),
         do: revoke(token)
  end

  @doc "Revokes access token"
  @spec revoke(Token.t()) :: {:ok, Token.t()} | {:error, Ecto.Changeset.t()}
  def revoke(%Token{} = token) do
    Repo.delete(token)
  end
end
