# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.Utils do
  @moduledoc """
  Some helper functions shared across several plugs
  """

  def get_safe_mime_type(%{allowed_mime_types: allowed_mime_types} = _opts, mime) do
    [maintype | _] = String.split(mime, "/", parts: 2)
    if maintype in allowed_mime_types, do: mime, else: "application/octet-stream"
  end
end
