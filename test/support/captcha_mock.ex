defmodule Pleroma.Captcha.Mock do
  alias Pleroma.Captcha.Service
  @behaviour Service

  @impl Service
  def new(), do: %{type: :mock}

  @impl Service
  def validate(_token, _captcha), do: true
end
