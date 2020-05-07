# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.TOTPAuthenticator do
  alias Comeonin.Pbkdf2
  alias Pleroma.MFA
  alias Pleroma.MFA.TOTP
  alias Pleroma.User

  @doc "Verify code or check backup code."
  @spec verify(String.t(), User.t()) ::
          {:ok, :pass} | {:error, :invalid_token | :invalid_secret_and_token}
  def verify(
        token,
        %User{
          multi_factor_authentication_settings:
            %{enabled: true, totp: %{secret: secret, confirmed: true}} = _
        } = _user
      )
      when is_binary(token) and byte_size(token) > 0 do
    TOTP.validate_token(secret, token)
  end

  def verify(_, _), do: {:error, :invalid_token}

  @spec verify_recovery_code(User.t(), String.t()) ::
          {:ok, :pass} | {:error, :invalid_token}
  def verify_recovery_code(
        %User{multi_factor_authentication_settings: %{enabled: true, backup_codes: codes}} = user,
        code
      )
      when is_list(codes) and is_binary(code) do
    hash_code = Enum.find(codes, fn hash -> Pbkdf2.checkpw(code, hash) end)

    if hash_code do
      MFA.invalidate_backup_code(user, hash_code)
      {:ok, :pass}
    else
      {:error, :invalid_token}
    end
  end

  def verify_recovery_code(_, _), do: {:error, :invalid_token}
end
