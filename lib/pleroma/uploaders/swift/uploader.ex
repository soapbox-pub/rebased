# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Uploaders.Swift do
  @behaviour Pleroma.Uploaders.Uploader

  def get_file(name) do
    {:ok, {:url, Path.join([Pleroma.Config.get!([__MODULE__, :object_url]), name])}}
  end

  def put_file(upload) do
    Pleroma.Uploaders.Swift.Client.upload_file(
      upload.path,
      File.read!(upload.tmpfile),
      upload.content_type
    )
  end
end
