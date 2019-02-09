# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth do
  def parse_scopes(scopes) do
    scopes
    |> to_string()
    |> String.split([" ", ","])
  end
end
