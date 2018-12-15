defmodule Pleroma.Captcha.Kocaptcha do
  alias Pleroma.Captcha.Service
  @behaviour Service

  @ets __MODULE__.Ets

  @impl Service
  def new() do
    endpoint = Pleroma.Config.get!([__MODULE__, :endpoint])

    case HTTPoison.get(endpoint <> "/new") do
      {:error, _} ->
        %{error: "Kocaptcha service unavailable"}

      {:ok, res} ->
        json_resp = Poison.decode!(res.body)

        token = json_resp["token"]

        true = :ets.insert(@ets, {token, json_resp["md5"]})

        %{type: :kocaptcha, token: token, url: endpoint <> json_resp["url"]}
    end
  end

  @impl Service
  def validate(token, captcha) do
    with false <- is_nil(captcha),
         [{^token, saved_md5}] <- :ets.lookup(@ets, token),
         true <- :crypto.hash(:md5, captcha) |> Base.encode16() == String.upcase(saved_md5) do
      # Clear the saved value
      :ets.delete(@ets, token)

      true
    else
      _ -> false
    end
  end
end
