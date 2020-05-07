# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MFATest do
  use Pleroma.DataCase

  import Pleroma.Factory
  alias Comeonin.Pbkdf2
  alias Pleroma.MFA

  describe "mfa_settings" do
    test "returns settings user's" do
      user =
        insert(:user,
          multi_factor_authentication_settings: %MFA.Settings{
            enabled: true,
            totp: %MFA.Settings.TOTP{secret: "xx", confirmed: true}
          }
        )

      settings = MFA.mfa_settings(user)
      assert match?(^settings, %{enabled: true, totp: true})
    end
  end

  describe "generate backup codes" do
    test "returns backup codes" do
      user = insert(:user)

      {:ok, [code1, code2]} = MFA.generate_backup_codes(user)
      updated_user = refresh_record(user)
      [hash1, hash2] = updated_user.multi_factor_authentication_settings.backup_codes
      assert Pbkdf2.checkpw(code1, hash1)
      assert Pbkdf2.checkpw(code2, hash2)
    end
  end

  describe "invalidate_backup_code" do
    test "invalid used code" do
      user = insert(:user)

      {:ok, _} = MFA.generate_backup_codes(user)
      user = refresh_record(user)
      assert length(user.multi_factor_authentication_settings.backup_codes) == 2
      [hash_code | _] = user.multi_factor_authentication_settings.backup_codes

      {:ok, user} = MFA.invalidate_backup_code(user, hash_code)

      assert length(user.multi_factor_authentication_settings.backup_codes) == 1
    end
  end
end
