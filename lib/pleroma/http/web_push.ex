# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.WebPush do
  @moduledoc false

  def post(url, payload, headers, options \\ []) do
    list_headers = Map.to_list(headers)
    Pleroma.HTTP.post(url, payload, list_headers, options)
  end
end
