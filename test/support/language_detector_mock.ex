# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule LanguageDetectorMock do
  alias Pleroma.Language.LanguageDetector.Provider

  @behaviour Provider

  @impl Provider
  def missing_dependencies, do: []

  @impl Provider
  def configured?, do: true

  @impl Provider
  def detect(_text), do: "fr"
end
