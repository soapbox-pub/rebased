# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser.Embed do
  @moduledoc """
  Represents embedded content, including scraped markup and OEmbed.
  """
  defstruct url: nil, title: nil, meta: nil, oembed: nil
end
