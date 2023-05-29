# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.OnlyMedia do
  @behaviour Pleroma.Upload.Filter
  alias Pleroma.Upload

  def filter(%Upload{content_type: content_type}) do
    [type, _subtype] = String.split(content_type, "/")

    if type in ["image", "video", "audio"] do
      {:ok, :noop}
    else
      {:error, "Disallowed content-type: #{content_type}"}
    end
  end

  def filter(_), do: {:ok, :noop}
end
