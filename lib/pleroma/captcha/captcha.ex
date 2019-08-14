# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Captcha do
  import Pleroma.Web.Gettext

  alias Calendar.DateTime
  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageEncryptor

  use GenServer

  @doc false
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc false
  def init(_) do
    {:ok, nil}
  end

  @doc """
  Ask the configured captcha service for a new captcha
  """
  def new do
    GenServer.call(__MODULE__, :new)
  end

  @doc """
  Ask the configured captcha service to validate the captcha
  """
  def validate(token, captcha, answer_data) do
    GenServer.call(__MODULE__, {:validate, token, captcha, answer_data})
  end

  @doc false
  def handle_call(:new, _from, state) do
    enabled = Pleroma.Config.get([__MODULE__, :enabled])

    if !enabled do
      {:reply, %{type: :none}, state}
    else
      new_captcha = method().new()

      secret_key_base = Pleroma.Config.get!([Pleroma.Web.Endpoint, :secret_key_base])

      # This make salt a little different for two keys
      token = new_captcha[:token]
      secret = KeyGenerator.generate(secret_key_base, token <> "_encrypt")
      sign_secret = KeyGenerator.generate(secret_key_base, token <> "_sign")
      # Basicallty copy what Phoenix.Token does here, add the time to
      # the actual data and make it a binary to then encrypt it
      encrypted_captcha_answer =
        %{
          at: DateTime.now_utc(),
          answer_data: new_captcha[:answer_data]
        }
        |> :erlang.term_to_binary()
        |> MessageEncryptor.encrypt(secret, sign_secret)

      {
        :reply,
        # Repalce the answer with the encrypted answer
        %{new_captcha | answer_data: encrypted_captcha_answer},
        state
      }
    end
  end

  @doc false
  def handle_call({:validate, token, captcha, answer_data}, _from, state) do
    secret_key_base = Pleroma.Config.get!([Pleroma.Web.Endpoint, :secret_key_base])
    secret = KeyGenerator.generate(secret_key_base, token <> "_encrypt")
    sign_secret = KeyGenerator.generate(secret_key_base, token <> "_sign")

    # If the time found is less than (current_time-seconds_valid) then the time has already passed
    # Later we check that the time found is more than the presumed invalidatation time, that means
    # that the data is still valid and the captcha can be checked
    seconds_valid = Pleroma.Config.get!([Pleroma.Captcha, :seconds_valid])
    valid_if_after = DateTime.subtract!(DateTime.now_utc(), seconds_valid)

    result =
      with {:ok, data} <- MessageEncryptor.decrypt(answer_data, secret, sign_secret),
           %{at: at, answer_data: answer_md5} <- :erlang.binary_to_term(data) do
        try do
          if DateTime.before?(at, valid_if_after),
            do: throw({:error, dgettext("errors", "CAPTCHA expired")})

          if not is_nil(Cachex.get!(:used_captcha_cache, token)),
            do: throw({:error, dgettext("errors", "CAPTCHA already used")})

          res = method().validate(token, captcha, answer_md5)
          # Throw if an error occurs
          if res != :ok, do: throw(res)

          # Mark this captcha as used
          {:ok, _} =
            Cachex.put(:used_captcha_cache, token, true, ttl: :timer.seconds(seconds_valid))

          :ok
        catch
          :throw, e -> e
        end
      else
        _ -> {:error, dgettext("errors", "Invalid answer data")}
      end

    {:reply, result, state}
  end

  defp method, do: Pleroma.Config.get!([__MODULE__, :method])
end
