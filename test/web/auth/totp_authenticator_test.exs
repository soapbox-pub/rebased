# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.TOTPAuthenticatorTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.MFA
  alias Pleroma.MFA.BackupCodes
  alias Pleroma.MFA.TOTP
  alias Pleroma.Web.Auth.TOTPAuthenticator

  import Pleroma.Factory

  test "verify token" do
    otp_secret = TOTP.generate_secret()
    otp_token = TOTP.generate_token(otp_secret)

    user =
      insert(:user,
        multi_factor_authentication_settings: %MFA.Settings{
          enabled: true,
          totp: %MFA.Settings.TOTP{secret: otp_secret, confirmed: true}
        }
      )

    assert TOTPAuthenticator.verify(otp_token, user) == {:ok, :pass}
    assert TOTPAuthenticator.verify(nil, user) == {:error, :invalid_token}
    assert TOTPAuthenticator.verify("", user) == {:error, :invalid_token}
  end

  test "checks backup codes" do
    [code | _] = backup_codes = BackupCodes.generate()

    hashed_codes =
      backup_codes
      |> Enum.map(&Comeonin.Pbkdf2.hashpwsalt(&1))

    user =
      insert(:user,
        multi_factor_authentication_settings: %MFA.Settings{
          enabled: true,
          backup_codes: hashed_codes,
          totp: %MFA.Settings.TOTP{secret: "otp_secret", confirmed: true}
        }
      )

    assert TOTPAuthenticator.verify_recovery_code(user, code) == {:ok, :pass}
    refute TOTPAuthenticator.verify_recovery_code(code, refresh_record(user)) == {:ok, :pass}
  end
end
