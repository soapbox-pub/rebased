# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Captcha.Native do
  import Pleroma.Web.Gettext
  alias Pleroma.Captcha.Service
  @behaviour Service

  @impl Service
  def new do
    case Captcha.get() do
      {:timeout} ->
        %{error: dgettext("errors", "Captcha timeout")}

      {:ok, answer_data, img_binary} ->
        %{
          type: :native,
          token: token(),
          url: "data:image/png;base64," <> Base.encode64(img_binary),
          answer_data: answer_data
        }
    end
  end

  @impl Service
  def validate(_token, captcha, captcha) when not is_nil(captcha), do: :ok
  def validate(_token, _captcha, _answer), do: {:error, dgettext("errors", "Invalid CAPTCHA")}

  defp token do
    10
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
