defmodule Pleroma.Web.RichMedia.Parser.TTL.AwsSignedUrl do
  @behaviour Pleroma.Web.RichMedia.Parser.TTL

  @impl Pleroma.Web.RichMedia.Parser.TTL
  def ttl(data, _url) do
    image = Map.get(data, :image)

    if is_aws_signed_url(image) do
      image
      |> parse_query_params()
      |> format_query_params()
      |> get_expiration_timestamp()
    end
  end

  defp is_aws_signed_url(""), do: nil
  defp is_aws_signed_url(nil), do: nil

  defp is_aws_signed_url(image) when is_binary(image) do
    %URI{host: host, query: query} = URI.parse(image)

    if String.contains?(host, "amazonaws.com") and String.contains?(query, "X-Amz-Expires") do
      image
    else
      nil
    end
  end

  defp is_aws_signed_url(_), do: nil

  defp parse_query_params(image) do
    %URI{query: query} = URI.parse(image)
    query
  end

  defp format_query_params(query) do
    query
    |> String.split(~r/&|=/)
    |> Enum.chunk_every(2)
    |> Map.new(fn [k, v] -> {k, v} end)
  end

  defp get_expiration_timestamp(params) when is_map(params) do
    {:ok, date} =
      params
      |> Map.get("X-Amz-Date")
      |> Timex.parse("{ISO:Basic:Z}")

    Timex.to_unix(date) + String.to_integer(Map.get(params, "X-Amz-Expires"))
  end
end
