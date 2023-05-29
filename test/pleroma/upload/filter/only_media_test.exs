# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.OnlyMediaTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Upload
  alias Pleroma.Upload.Filter.OnlyMedia

  test "Allows media Content-Type" do
    ["audio/mpeg", "image/jpeg", "video/mp4"]
    |> Enum.each(fn type ->
      upload = %Upload{
        content_type: type
      }

      assert {:ok, :noop} = OnlyMedia.filter(upload)
    end)
  end

  test "Disallows non-media Content-Type" do
    ["application/javascript", "application/pdf", "text/html"]
    |> Enum.each(fn type ->
      upload = %Upload{
        content_type: type
      }

      assert {:error, _} = OnlyMedia.filter(upload)
    end)
  end
end
