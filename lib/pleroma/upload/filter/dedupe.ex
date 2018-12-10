defmodule Pleroma.Upload.Filter.Dedupe do
  @behaviour Pleroma.Upload.Filter
  alias Pleroma.Upload

  def filter(upload = %Upload{name: name}) do
    extension = String.split(name, ".") |> List.last()
    shasum = :crypto.hash(:sha256, File.read!(upload.tempfile)) |> Base.encode16(case: :lower)
    filename = shasum <> "." <> extension
    {:ok, %Upload{upload | id: shasum, path: filename}}
  end
end
