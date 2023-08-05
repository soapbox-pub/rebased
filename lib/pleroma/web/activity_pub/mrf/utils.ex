# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.Utils do
  @spec describe_regex_or_string(String.t() | Regex.t()) :: String.t()
  def describe_regex_or_string(pattern) do
    # This horror is needed to convert regex sigils to strings
    if not is_binary(pattern) do
      inspect(pattern)
    else
      pattern
    end
  end
end
