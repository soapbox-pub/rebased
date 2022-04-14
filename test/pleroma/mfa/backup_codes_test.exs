# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MFA.BackupCodesTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.MFA.BackupCodes

  test "generate backup codes" do
    codes = BackupCodes.generate(number_of_codes: 2, length: 4)

    assert [<<_::bytes-size(4)>>, <<_::bytes-size(4)>>] = codes
  end
end
