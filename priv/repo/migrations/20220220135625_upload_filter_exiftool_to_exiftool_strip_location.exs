defmodule Pleroma.Repo.Migrations.UploadFilterExiftoolToExiftoolStripLocation do
  use Ecto.Migration

  alias Pleroma.ConfigDB

  def up,
    do:
      ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Upload})
      |> update_filtername(
        Pleroma.Upload.Filter.Exiftool,
        Pleroma.Upload.Filter.Exiftool.StripLocation
      )

  def down,
    do:
      ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Upload})
      |> update_filtername(
        Pleroma.Upload.Filter.Exiftool.StripLocation,
        Pleroma.Upload.Filter.Exiftool
      )

  defp update_filtername(%{value: value}, from_filtername, to_filtername) do
    new_filters =
      value[:filters]
      |> Enum.map(fn
        ^from_filtername -> to_filtername
        filter -> filter
      end)

    new_value = value |> Keyword.update(:filters, [], fn _ -> new_filters end)

    ConfigDB.update_or_create(%{group: :pleroma, key: Pleroma.Upload, value: new_value})
  end
end
