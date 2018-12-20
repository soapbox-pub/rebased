defmodule Pleroma.Captcha.Service do
  @doc """
  Request new captcha from a captcha service.

  Returns:

  Service-specific data for using the newly created captcha
  """
  @callback new() :: map

  @doc """
  Validated the provided captcha solution.

  Arguments:
  * `token` the captcha is associated with
  * `captcha` solution of the captcha to validate
  * `answer_data` is the data needed to validate the answer (presumably encrypted)

  Returns:

  `true` if captcha is valid, `false` if not
  """
  @callback validate(
              token :: String.t(),
              captcha :: String.t(),
              answer_data :: String.t()
            ) :: :ok | {:error, String.t()}
end
