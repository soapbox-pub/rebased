defmodule Pleroma.Upload.Filter.AnonymizeFilename do
  @moduledoc """
  Replaces the original filename with a pre-defined text or randomly generated string.

  Should be used after `Pleroma.Upload.Filter.Dedupe`.
  """
  @behaviour Pleroma.Upload.Filter

  def filter(upload) do
    extension = List.last(String.split(upload.name, "."))
    name = Pleroma.Config.get([__MODULE__, :text], random(extension))
    {:ok, %Pleroma.Upload{upload | name: name}}
  end

  defp random(extension) do
    string =
      10
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64(padding: false)

    string <> "." <> extension
  end
end
