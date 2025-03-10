# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.UploadedMediaTest do
  use Pleroma.Web.ConnCase, async: false

  alias Pleroma.StaticStubbedConfigMock
  alias Pleroma.Web.Plugs.Utils

  setup do
    Mox.stub_with(StaticStubbedConfigMock, Pleroma.Test.StaticConfig)

    {:ok, %{}}
  end

  describe "content-type sanitization with Utils.get_safe_mime_type/2" do
    test "it allows safe MIME types" do
      opts = %{allowed_mime_types: ["image", "audio", "video"]}

      assert Utils.get_safe_mime_type(opts, "image/jpeg") == "image/jpeg"
      assert Utils.get_safe_mime_type(opts, "audio/mpeg") == "audio/mpeg"
      assert Utils.get_safe_mime_type(opts, "video/mp4") == "video/mp4"
    end

    test "it sanitizes potentially dangerous content-types" do
      opts = %{allowed_mime_types: ["image", "audio", "video"]}

      assert Utils.get_safe_mime_type(opts, "application/activity+json") ==
               "application/octet-stream"

      assert Utils.get_safe_mime_type(opts, "text/html") == "application/octet-stream"

      assert Utils.get_safe_mime_type(opts, "application/javascript") ==
               "application/octet-stream"
    end
  end
end
