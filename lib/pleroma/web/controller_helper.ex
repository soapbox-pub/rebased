# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ControllerHelper do
  use Pleroma.Web, :controller

  # As in MastoAPI, per https://api.rubyonrails.org/classes/ActiveModel/Type/Boolean.html
  @falsy_param_values [false, 0, "0", "f", "F", "false", "FALSE", "off", "OFF"]
  def truthy_param?(blank_value) when blank_value in [nil, ""], do: nil
  def truthy_param?(value), do: value not in @falsy_param_values

  def json_response(conn, status, json) do
    conn
    |> put_status(status)
    |> json(json)
  end
end
