# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Language.LanguageDetectorTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Language.LanguageDetector

  setup do: clear_config([Pleroma.Language.LanguageDetector, :provider], LanguageDetectorMock)

  test "it detects text language" do
    detected_language = LanguageDetector.detect("Je viens d'atterrir en Tchéquie.")

    assert detected_language == "fr"
  end

  test "it returns nil if text is not long enough" do
    detected_language = LanguageDetector.detect("it returns nil")

    assert detected_language == nil
  end

  test "it returns nil if no provider specified" do
    clear_config([Pleroma.Language.LanguageDetector, :provider], nil)

    detected_language = LanguageDetector.detect("this should also return nil")

    assert detected_language == nil
  end
end
