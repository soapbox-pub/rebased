# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.KeysTest do
  use Pleroma.DataCase

  alias Pleroma.Keys

  test "generates an RSA private key pem" do
    {:ok, key} = Keys.generate_rsa_pem()

    assert is_binary(key)
    assert Regex.match?(~r/RSA/, key)
  end

  test "returns a public and private key from a pem" do
    pem = File.read!("test/fixtures/private_key.pem")
    {:ok, private, public} = Keys.keys_from_pem(pem)

    assert elem(private, 0) == :RSAPrivateKey
    assert elem(public, 0) == :RSAPublicKey
  end
end
