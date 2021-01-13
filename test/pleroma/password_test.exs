# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.PasswordTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Password

  test "it generates the same hash as pbkd2_elixir" do
    # hash = Pleroma.Password.hash_pwd_salt("password")
    hash =
      "$pbkdf2-sha512$1$QJpEYw8iBKcnY.4Rm0eCVw$UBPeWQ91RxSv3snxsb/ZzMeG/2aa03c541bbo8vQudREGNta5t8jBQrd00fyJp8RjaqfvgdZxy2rhSwljyu21g"

    # Use the same randomly generated salt
    salt = Password.decode64("QJpEYw8iBKcnY.4Rm0eCVw")

    assert hash == Password.hash_pwd_salt("password", salt: salt)
  end

  @tag skip: "Works when Pbkd2 is present. Source: trust me bro"
  test "Pleroma.Password can verify passwords generated with it" do
    hash = Password.hash_pwd_salt("password")

    assert Pleroma.Password.verify_pass("password", hash)
  end

  test "it verifies pbkdf2_elixir hashes" do
    # hash = Pleroma.Password.hash_pwd_salt("password")
    hash =
      "$pbkdf2-sha512$1$QJpEYw8iBKcnY.4Rm0eCVw$UBPeWQ91RxSv3snxsb/ZzMeG/2aa03c541bbo8vQudREGNta5t8jBQrd00fyJp8RjaqfvgdZxy2rhSwljyu21g"

    assert Password.verify_pass("password", hash)
  end
end
