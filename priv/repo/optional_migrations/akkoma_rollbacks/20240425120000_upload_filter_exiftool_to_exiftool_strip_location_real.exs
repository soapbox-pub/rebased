# Adapted from Akkoma
# https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/priv/repo/migrations/20240425120000_upload_filter_exiftool_to_exiftool_strip_location_real.exs

defmodule Pleroma.Repo.Migrations.UploadFilterExiftoolToExiftoolStripMetadataReal do
  use Ecto.Migration

  alias Pleroma.ConfigDB

  def up, do: :ok

  def down,
    do:
      ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Upload})
      |> update_filtername(
        Pleroma.Upload.Filter.Exiftool.StripMetadata,
        Pleroma.Upload.Filter.Exiftool
      )

  defp update_filtername(%{value: value}, from_filtername, to_filtername) do
    new_value =
      value
      |> Keyword.update(:filters, [], fn filters ->
        filters
        |> Enum.map(fn
          ^from_filtername -> to_filtername
          filter -> filter
        end)
      end)

    ConfigDB.update_or_create(%{group: :pleroma, key: Pleroma.Upload, value: new_value})
  end

  defp update_filtername(_, _, _), do: nil
end
