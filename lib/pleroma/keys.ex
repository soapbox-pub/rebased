# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Keys do
  # Native generation of RSA keys is only available since OTP 20+ and in default build conditions
  # We try at compile time to generate natively an RSA key otherwise we fallback on the old way.
  try do
    _ = :public_key.generate_key({:rsa, 2048, 65_537})

    def generate_rsa_pem do
      key = :public_key.generate_key({:rsa, 2048, 65_537})
      entry = :public_key.pem_entry_encode(:RSAPrivateKey, key)
      pem = :public_key.pem_encode([entry]) |> String.trim_trailing()
      {:ok, pem}
    end
  rescue
    _ ->
      def generate_rsa_pem do
        port = Port.open({:spawn, "openssl genrsa"}, [:binary])

        {:ok, pem} =
          receive do
            {^port, {:data, pem}} -> {:ok, pem}
          end

        Port.close(port)

        if Regex.match?(~r/RSA PRIVATE KEY/, pem) do
          {:ok, pem}
        else
          :error
        end
      end
  end

  def keys_from_pem(pem) do
    with [private_key_code] <- :public_key.pem_decode(pem),
         private_key <- :public_key.pem_entry_decode(private_key_code),
         {:RSAPrivateKey, _, modulus, exponent, _, _, _, _, _, _, _} <- private_key do
      {:ok, private_key, {:RSAPublicKey, modulus, exponent}}
    else
      error -> {:error, error}
    end
  end
end
