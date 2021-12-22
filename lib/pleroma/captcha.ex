# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Captcha do
  alias Calendar.DateTime
  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageEncryptor

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  @doc """
  Ask the configured captcha service for a new captcha
  """
  def new do
    if not enabled?() do
      %{type: :none}
    else
      new_captcha = method().new()

      # This make salt a little different for two keys
      {secret, sign_secret} = secret_pair(new_captcha[:token])

      # Basically copy what Phoenix.Token does here, add the time to
      # the actual data and make it a binary to then encrypt it
      encrypted_captcha_answer =
        %{
          at: DateTime.now_utc(),
          answer_data: new_captcha[:answer_data]
        }
        |> :erlang.term_to_binary()
        |> MessageEncryptor.encrypt(secret, sign_secret)

      # Replace the answer with the encrypted answer
      %{new_captcha | answer_data: encrypted_captcha_answer}
    end
  end

  @doc """
  Ask the configured captcha service to validate the captcha
  """
  def validate(token, captcha, answer_data) do
    with {:ok, %{at: at, answer_data: answer_md5}} <- validate_answer_data(token, answer_data),
         :ok <- validate_expiration(at),
         :ok <- validate_usage(token),
         :ok <- method().validate(token, captcha, answer_md5),
         {:ok, _} <- mark_captcha_as_used(token) do
      :ok
    end
  end

  def enabled?, do: Pleroma.Config.get([__MODULE__, :enabled], false)

  defp seconds_valid, do: Pleroma.Config.get!([__MODULE__, :seconds_valid])

  defp secret_pair(token) do
    secret_key_base = Pleroma.Config.get!([Pleroma.Web.Endpoint, :secret_key_base])
    secret = KeyGenerator.generate(secret_key_base, token <> "_encrypt")
    sign_secret = KeyGenerator.generate(secret_key_base, token <> "_sign")

    {secret, sign_secret}
  end

  defp validate_answer_data(token, answer_data) do
    {secret, sign_secret} = secret_pair(token)

    with false <- is_nil(answer_data),
         {:ok, data} <- MessageEncryptor.decrypt(answer_data, secret, sign_secret),
         %{at: at, answer_data: answer_md5} <- :erlang.binary_to_term(data) do
      {:ok, %{at: at, answer_data: answer_md5}}
    else
      _ -> {:error, :invalid_answer_data}
    end
  end

  defp validate_expiration(created_at) do
    # If the time found is less than (current_time-seconds_valid) then the time has already passed
    # Later we check that the time found is more than the presumed invalidatation time, that means
    # that the data is still valid and the captcha can be checked

    valid_if_after = DateTime.subtract!(DateTime.now_utc(), seconds_valid())

    if DateTime.before?(created_at, valid_if_after) do
      {:error, :expired}
    else
      :ok
    end
  end

  defp validate_usage(token) do
    if is_nil(@cachex.get!(:used_captcha_cache, token)) do
      :ok
    else
      {:error, :already_used}
    end
  end

  defp mark_captcha_as_used(token) do
    ttl = seconds_valid() |> :timer.seconds()
    @cachex.put(:used_captcha_cache, token, true, ttl: ttl)
  end

  defp method, do: Pleroma.Config.get!([__MODULE__, :method])
end
