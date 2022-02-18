# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.SetMeta do
  # This filter was renamed to AnalyzeMetadata.
  # Include this module for backwards compatibilty.
  defdelegate filter(upload), to: Pleroma.Upload.Filter.AnalyzeMetadata
end
