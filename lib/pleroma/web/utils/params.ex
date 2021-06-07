# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Utils.Params do
  # As in Mastodon API, per https://api.rubyonrails.org/classes/ActiveModel/Type/Boolean.html
  @falsy_param_values [false, 0, "0", "f", "F", "false", "False", "FALSE", "off", "OFF"]

  defp explicitly_falsy_param?(value), do: value in @falsy_param_values

  # Note: `nil` and `""` are considered falsy values in Pleroma
  defp falsy_param?(value),
    do: explicitly_falsy_param?(value) or value in [nil, ""]

  def truthy_param?(value), do: not falsy_param?(value)
end
