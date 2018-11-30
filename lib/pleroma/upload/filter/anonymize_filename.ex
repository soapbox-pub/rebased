defmodule Pleroma.Upload.Filter.AnonymizeFilename do
  @moduledoc "Replaces the original filename with a randomly generated string."
  @behaviour Pleroma.Upload.Filter

  def filter(upload) do
    extension = List.last(String.split(upload.name, "."))
    string = Base.url_encode64(:crypto.strong_rand_bytes(10), padding: false)
    {:ok, %Pleroma.Upload{upload | name: string <> "." <> extension}}
  end
end
