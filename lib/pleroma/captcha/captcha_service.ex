# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Captcha.Service do
  @doc """
  Request new captcha from a captcha service.

  Returns:

  Type/Name of the service, the token to identify the captcha,
  the data of the answer and service-specific data to use the newly created captcha
  """
  @callback new() :: %{
              type: atom(),
              token: String.t(),
              answer_data: any()
            }

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
              answer_data :: any()
            ) :: :ok | {:error, String.t()}
end
