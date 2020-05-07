defmodule Pleroma.MFA.TOTPTest do
  use Pleroma.DataCase

  alias Pleroma.MFA.TOTP

  test "create provisioning_uri to generate qrcode" do
    uri =
      TOTP.provisioning_uri("test-secrcet", "test@example.com",
        issuer: "Plerome-42",
        digits: 8,
        period: 60
      )

    assert uri ==
             "otpauth://totp/test@example.com?digits=8&issuer=Plerome-42&period=60&secret=test-secrcet"
  end
end
