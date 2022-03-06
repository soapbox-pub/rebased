# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Password.Pbkdf2 do
  @moduledoc """
  This module implements Pbkdf2 passwords in terms of Plug.Crypto.
  """

  alias Plug.Crypto.KeyGenerator

  def decode64(str) do
    str
    |> String.replace(".", "+")
    |> Base.decode64!(padding: false)
  end

  def encode64(bin) do
    bin
    |> Base.encode64(padding: false)
    |> String.replace("+", ".")
  end

  def verify_pass(password, hash) do
    ["pbkdf2-" <> digest, iterations, salt, hash] = String.split(hash, "$", trim: true)

    salt = decode64(salt)

    iterations = String.to_integer(iterations)

    digest = String.to_atom(digest)

    binary_hash =
      KeyGenerator.generate(password, salt, digest: digest, iterations: iterations, length: 64)

    encode64(binary_hash) == hash
  end

  def hash_pwd_salt(password, opts \\ []) do
    salt =
      Keyword.get_lazy(opts, :salt, fn ->
        :crypto.strong_rand_bytes(16)
      end)

    digest = Keyword.get(opts, :digest, :sha512)

    iterations =
      Keyword.get(opts, :iterations, Pleroma.Config.get([:password, :iterations], 160_000))

    binary_hash =
      KeyGenerator.generate(password, salt, digest: digest, iterations: iterations, length: 64)

    "$pbkdf2-#{digest}$#{iterations}$#{encode64(salt)}$#{encode64(binary_hash)}"
  end
end
