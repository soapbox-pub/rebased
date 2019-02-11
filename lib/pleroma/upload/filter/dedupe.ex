# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.Dedupe do
  @behaviour Pleroma.Upload.Filter
  alias Pleroma.Upload

  def filter(%Upload{name: name} = upload) do
    extension = String.split(name, ".") |> List.last()
    shasum = :crypto.hash(:sha256, File.read!(upload.tempfile)) |> Base.encode16(case: :lower)
    filename = shasum <> "." <> extension
    {:ok, %Upload{upload | id: shasum, path: filename}}
  end
end
