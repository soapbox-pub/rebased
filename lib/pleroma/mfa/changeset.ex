# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MFA.Changeset do
  alias Pleroma.MFA
  alias Pleroma.MFA.Settings
  alias Pleroma.User

  def disable(%Ecto.Changeset{} = changeset, force \\ false) do
    settings =
      changeset
      |> Ecto.Changeset.apply_changes()
      |> MFA.fetch_settings()

    if force || not MFA.enabled?(settings) do
      put_change(changeset, %Settings{settings | enabled: false})
    else
      changeset
    end
  end

  def disable_totp(%User{multi_factor_authentication_settings: settings} = user) do
    user
    |> put_change(%Settings{settings | totp: %Settings.TOTP{}})
  end

  def confirm_totp(%User{multi_factor_authentication_settings: settings} = user) do
    totp_settings = %Settings.TOTP{settings.totp | confirmed: true}

    user
    |> put_change(%Settings{settings | totp: totp_settings, enabled: true})
  end

  def setup_totp(%User{} = user, attrs) do
    mfa_settings = MFA.fetch_settings(user)

    totp_settings =
      %Settings.TOTP{}
      |> Ecto.Changeset.cast(attrs, [:secret, :delivery_type])

    user
    |> put_change(%Settings{mfa_settings | totp: Ecto.Changeset.apply_changes(totp_settings)})
  end

  def cast_backup_codes(%User{} = user, codes) do
    user
    |> put_change(%Settings{
      user.multi_factor_authentication_settings
      | backup_codes: codes
    })
  end

  defp put_change(%User{} = user, settings) do
    user
    |> Ecto.Changeset.change()
    |> put_change(settings)
  end

  defp put_change(%Ecto.Changeset{} = changeset, settings) do
    changeset
    |> Ecto.Changeset.put_change(:multi_factor_authentication_settings, settings)
  end
end
