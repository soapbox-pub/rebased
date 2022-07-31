# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Password.Pbkdf2Test do
  use Pleroma.DataCase, async: true

  alias Pleroma.Password.Pbkdf2, as: Password

  test "it generates the same hash as pbkd2_elixir" do
    # hash = Pbkdf2.hash_pwd_salt("password")
    hash =
      "$pbkdf2-sha512$1$QJpEYw8iBKcnY.4Rm0eCVw$UBPeWQ91RxSv3snxsb/ZzMeG/2aa03c541bbo8vQudREGNta5t8jBQrd00fyJp8RjaqfvgdZxy2rhSwljyu21g"

    # Use the same randomly generated salt
    salt = Password.decode64("QJpEYw8iBKcnY.4Rm0eCVw")

    assert hash == Password.hash_pwd_salt("password", salt: salt)
  end

  @tag skip: "Works when Pbkd2 is present. Source: trust me bro"
  test "Pbkdf2 can verify passwords generated with it" do
    # Commented to prevent warnings.
    # hash = Password.hash_pwd_salt("password")
    # assert Pbkdf2.verify_pass("password", hash)
  end

  test "it verifies pbkdf2_elixir hashes" do
    # hash = Pbkdf2.hash_pwd_salt("password")
    hash =
      "$pbkdf2-sha512$1$QJpEYw8iBKcnY.4Rm0eCVw$UBPeWQ91RxSv3snxsb/ZzMeG/2aa03c541bbo8vQudREGNta5t8jBQrd00fyJp8RjaqfvgdZxy2rhSwljyu21g"

    assert Password.verify_pass("password", hash)
  end
end
