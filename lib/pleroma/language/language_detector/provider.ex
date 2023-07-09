# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Language.LanguageDetector.Provider do
  @callback missing_dependencies() :: [String.t()]

  @callback configured?() :: boolean()

  @callback detect(text :: String.t()) :: String.t() | nil
end
