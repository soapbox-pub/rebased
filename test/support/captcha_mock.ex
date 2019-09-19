# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Captcha.Mock do
  alias Pleroma.Captcha.Service
  @behaviour Service

  @impl Service
  def new, do: %{type: :mock}

  @impl Service
  def validate(_token, _captcha, _data), do: :ok
end
