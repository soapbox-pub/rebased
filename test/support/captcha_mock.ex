# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Captcha.Mock do
  alias Pleroma.Captcha.Service
  @behaviour Service

  @impl Service
  def new,
    do: %{
      type: :mock,
      token: "afa1815e14e29355e6c8f6b143a39fa2",
      answer_data: "63615261b77f5354fb8c4e4986477555",
      url: "https://example.org/captcha.png"
    }

  @impl Service
  def validate(_token, captcha, captcha) when not is_nil(captcha), do: :ok

  def validate(_token, captcha, answer),
    do: {:error, "Invalid CAPTCHA captcha: #{inspect(captcha)} ; answer: #{inspect(answer)}"}
end
