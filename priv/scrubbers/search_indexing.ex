# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTML.Scrubber.SearchIndexing do
  @moduledoc """
  An HTML scrubbing policy that scrubs things for searching.
  """

  require FastSanitize.Sanitizer.Meta
  alias FastSanitize.Sanitizer.Meta

  # Explicitly remove mentions
  def scrub({:a, attrs, children}) do
    if(Enum.any?(attrs, fn {att, val} -> att == "class" and String.contains?(val, "mention") end),
      do: nil,
      # Strip the tag itself, leave only children (text, presumably)
      else: children
    )
  end

  Meta.strip_comments()
  Meta.strip_everything_not_covered()
end
