# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Captcha.Kocaptcha do
  alias Pleroma.Captcha.Service
  @behaviour Service

  @impl Service
  def new do
    endpoint = Pleroma.Config.get!([__MODULE__, :endpoint])

    case Pleroma.HTTP.get(endpoint <> "/new") do
      {:error, _} ->
        %{error: :kocaptcha_service_unavailable}

      {:ok, res} ->
        json_resp = Jason.decode!(res.body)

        %{
          type: :kocaptcha,
          token: json_resp["token"],
          url: endpoint <> json_resp["url"],
          answer_data: json_resp["md5"],
          seconds_valid: Pleroma.Config.get([Pleroma.Captcha, :seconds_valid])
        }
    end
  end

  @impl Service
  def validate(_token, captcha, answer_data) do
    # Here the token is unsed, because the unencrypted captcha answer is just passed to method
    if not is_nil(captcha) and
         :crypto.hash(:md5, captcha) |> Base.encode16() == String.upcase(answer_data),
       do: :ok,
       else: {:error, :invalid}
  end
end
