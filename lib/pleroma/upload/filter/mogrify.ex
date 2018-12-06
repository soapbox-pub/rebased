defmodule Pleroma.Upload.Filter.Mogrify do
  @behaviour Pleroma.Uploader.Filter

  @type conversion :: action :: String.t() | {action :: String.t(), opts :: String.t()}
  @type conversions :: conversion() | [conversion()]

  def filter(%Pleroma.Upload{tempfile: file, content_type: "image" <> _}) do
    filters = Pleroma.Config.get!([__MODULE__, :args])

    file
    |> Mogrify.open()
    |> mogrify_filter(filters)
    |> Mogrify.save(in_place: true)

    :ok
  end

  def filter(_), do: :ok

  defp mogrify_filter(mogrify, nil), do: mogrify

  defp mogrify_filter(mogrify, [filter | rest]) do
    mogrify
    |> mogrify_filter(filter)
    |> mogrify_filter(rest)
  end

  defp mogrify_filter(mogrify, []), do: mogrify

  defp mogrify_filter(mogrify, {action, options}) do
    Mogrify.custom(mogrify, action, options)
  end

  defp mogrify_filter(mogrify, action) when is_binary(action) do
    Mogrify.custom(mogrify, action)
  end
end
