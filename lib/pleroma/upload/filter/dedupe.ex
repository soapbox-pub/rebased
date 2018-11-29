defmodule Pleroma.Upload.Filter.Dedupe do
  @behaviour Pleroma.Upload.Filter

  def filter(upload = %Pleroma.Upload{name: name, tempfile: path}) do
    extension = String.split(name, ".") |> List.last()
    shasum = :crypto.hash(:sha256, File.read!(upload.tempfile)) |> Base.encode16(case: :lower)
    filename = shasum <> "." <> extension
    {:ok, %Pleroma.Upload{upload | id: shasum, path: filename}}
  end
end
