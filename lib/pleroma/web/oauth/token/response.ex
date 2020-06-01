# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.Token.Response do
  @moduledoc false

  alias Pleroma.MFA
  alias Pleroma.User
  alias Pleroma.Web.OAuth.Token.Utils

  @doc false
  def build(%User{} = user, token, opts \\ %{}) do
    %{
      token_type: "Bearer",
      access_token: token.token,
      refresh_token: token.refresh_token,
      expires_in: expires_in(),
      scope: Enum.join(token.scopes, " "),
      me: user.ap_id
    }
    |> Map.merge(opts)
  end

  def build_for_client_credentials(token) do
    %{
      token_type: "Bearer",
      access_token: token.token,
      refresh_token: token.refresh_token,
      created_at: Utils.format_created_at(token),
      expires_in: expires_in(),
      scope: Enum.join(token.scopes, " ")
    }
  end

  def build_for_mfa_token(user, mfa_token) do
    %{
      error: "mfa_required",
      mfa_token: mfa_token.token,
      supported_challenge_types: MFA.supported_methods(user)
    }
  end

  defp expires_in, do: Pleroma.Config.get([:oauth2, :token_expires_in], 600)
end
