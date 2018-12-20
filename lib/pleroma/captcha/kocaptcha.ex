defmodule Pleroma.Captcha.Kocaptcha do
  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageEncryptor
  alias Calendar.DateTime

  alias Pleroma.Captcha.Service
  @behaviour Service

  @impl Service
  def new() do
    endpoint = Pleroma.Config.get!([__MODULE__, :endpoint])

    case Tesla.get(endpoint <> "/new") do
      {:error, _} ->
        %{error: "Kocaptcha service unavailable"}

      {:ok, res} ->
        json_resp = Poison.decode!(res.body)

        token = json_resp["token"]
        answer_md5 = json_resp["md5"]

        secret_key_base = Pleroma.Config.get!([Pleroma.Web.Endpoint, :secret_key_base])

        # This make salt a little different for two keys
        secret = KeyGenerator.generate(secret_key_base, token <> "_encrypt")
        sign_secret = KeyGenerator.generate(secret_key_base, token <> "_sign")
        # Basicallty copy what Phoenix.Token does here, add the time to
        # the actual data and make it a binary to then encrypt it
        encrypted_captcha_answer =
          %{
            at: DateTime.now_utc(),
            answer_md5: answer_md5
          }
          |> :erlang.term_to_binary()
          |> MessageEncryptor.encrypt(secret, sign_secret)

        %{
          type: :kocaptcha,
          token: token,
          url: endpoint <> json_resp["url"],
          answer_data: encrypted_captcha_answer
        }
    end
  end

  @impl Service
  def validate(token, captcha, answer_data) do
    secret_key_base = Pleroma.Config.get!([Pleroma.Web.Endpoint, :secret_key_base])
    secret = KeyGenerator.generate(secret_key_base, token <> "_encrypt")
    sign_secret = KeyGenerator.generate(secret_key_base, token <> "_sign")

    # If the time found is less than (current_time - seconds_valid), then the time has already passed.
    # Later we check that the time found is more than the presumed invalidatation time, that means
    # that the data is still valid and the captcha can be checked
    seconds_valid = Pleroma.Config.get!([Pleroma.Captcha, :seconds_valid])
    valid_if_after = DateTime.subtract!(DateTime.now_utc(), seconds_valid)

    with {:ok, data} <- MessageEncryptor.decrypt(answer_data, secret, sign_secret),
         %{at: at, answer_md5: answer_md5} <- :erlang.binary_to_term(data) do
      if DateTime.after?(at, valid_if_after) do
        if not is_nil(captcha) and
             :crypto.hash(:md5, captcha) |> Base.encode16() == String.upcase(answer_md5),
           do: :ok,
           else: {:error, "Invalid CAPTCHA"}
      else
        {:error, "CAPTCHA expired"}
      end
    else
      _ -> {:error, "Invalid answer data"}
    end
  end
end
