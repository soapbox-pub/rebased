# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parsers.OGP do
  @deprecated "OGP parser is deprecated. Use TwitterCard instead."
  def parse(_html, _data) do
    %{}
  end
end
