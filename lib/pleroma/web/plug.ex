# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plug do
  # Substitute for `call/2` which is defined with `use Pleroma.Web, :plug`
  @callback perform(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
end
