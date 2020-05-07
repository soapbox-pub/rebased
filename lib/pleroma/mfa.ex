# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MFA do
  @moduledoc """
  The MFA context.
  """

  alias Comeonin.Pbkdf2
  alias Pleroma.User

  alias Pleroma.MFA.BackupCodes
  alias Pleroma.MFA.Changeset
  alias Pleroma.MFA.Settings
  alias Pleroma.MFA.TOTP

  @doc """
  Returns MFA methods the user has enabled.

  ## Examples

    iex> Pleroma.MFA.supported_method(User)
    "totp, u2f"
  """
  @spec supported_methods(User.t()) :: String.t()
  def supported_methods(user) do
    settings = fetch_settings(user)

    Settings.mfa_methods()
    |> Enum.reduce([], fn m, acc ->
      if method_enabled?(m, settings) do
        acc ++ [m]
      else
        acc
      end
    end)
    |> Enum.join(",")
  end

  @doc "Checks that user enabled MFA"
  def require?(user) do
    fetch_settings(user).enabled
  end

  @doc """
  Display MFA settings of user
  """
  def mfa_settings(user) do
    settings = fetch_settings(user)

    Settings.mfa_methods()
    |> Enum.map(fn m -> [m, method_enabled?(m, settings)] end)
    |> Enum.into(%{enabled: settings.enabled}, fn [a, b] -> {a, b} end)
  end

  @doc false
  def fetch_settings(%User{} = user) do
    user.multi_factor_authentication_settings || %Settings{}
  end

  @doc "clears backup codes"
  def invalidate_backup_code(%User{} = user, hash_code) do
    %{backup_codes: codes} = fetch_settings(user)

    user
    |> Changeset.cast_backup_codes(codes -- [hash_code])
    |> User.update_and_set_cache()
  end

  @doc "generates backup codes"
  @spec generate_backup_codes(User.t()) :: {:ok, list(binary)} | {:error, String.t()}
  def generate_backup_codes(%User{} = user) do
    with codes <- BackupCodes.generate(),
         hashed_codes <- Enum.map(codes, &Pbkdf2.hashpwsalt/1),
         changeset <- Changeset.cast_backup_codes(user, hashed_codes),
         {:ok, _} <- User.update_and_set_cache(changeset) do
      {:ok, codes}
    else
      {:error, msg} ->
        %{error: msg}
    end
  end

  @doc """
  Generates secret key and set delivery_type to 'app' for TOTP method.
  """
  @spec setup_totp(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def setup_totp(user) do
    user
    |> Changeset.setup_totp(%{secret: TOTP.generate_secret(), delivery_type: "app"})
    |> User.update_and_set_cache()
  end

  @doc """
  Confirms the TOTP method for user.

  `attrs`:
    `password` - current user password
    `code` - TOTP token
  """
  @spec confirm_totp(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t() | atom()}
  def confirm_totp(%User{} = user, attrs) do
    with settings <- user.multi_factor_authentication_settings.totp,
         {:ok, :pass} <- TOTP.validate_token(settings.secret, attrs["code"]) do
      user
      |> Changeset.confirm_totp()
      |> User.update_and_set_cache()
    end
  end

  @doc """
  Disables the TOTP method for user.

  `attrs`:
    `password` - current user password
  """
  @spec disable_totp(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def disable_totp(%User{} = user) do
    user
    |> Changeset.disable_totp()
    |> Changeset.disable()
    |> User.update_and_set_cache()
  end

  @doc """
  Force disables all MFA methods for user.
  """
  @spec disable(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def disable(%User{} = user) do
    user
    |> Changeset.disable_totp()
    |> Changeset.disable(true)
    |> User.update_and_set_cache()
  end

  @doc """
  Checks if the user has MFA method enabled.
  """
  def method_enabled?(method, settings) do
    with {:ok, %{confirmed: true} = _} <- Map.fetch(settings, method) do
      true
    else
      _ -> false
    end
  end

  @doc """
  Checks if the user has enabled at least one MFA method.
  """
  def enabled?(settings) do
    Settings.mfa_methods()
    |> Enum.map(fn m -> method_enabled?(m, settings) end)
    |> Enum.any?()
  end
end
