defmodule Pleroma.MFA.BackupCodesTest do
  use Pleroma.DataCase

  alias Pleroma.MFA.BackupCodes

  test "generate backup codes" do
    codes = BackupCodes.generate(number_of_codes: 2, length: 4)

    assert [<<_::bytes-size(4)>>, <<_::bytes-size(4)>>] = codes
  end
end
