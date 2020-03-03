# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.TTL.AwsSignedUrlTest do
  use ExUnit.Case, async: true

  test "s3 signed url is parsed correct for expiration time" do
    url = "https://pleroma.social/amz"

    {:ok, timestamp} =
      Timex.now()
      |> DateTime.truncate(:second)
      |> Timex.format("{ISO:Basic:Z}")

    # in seconds
    valid_till = 30

    metadata = construct_metadata(timestamp, valid_till, url)

    expire_time =
      Timex.parse!(timestamp, "{ISO:Basic:Z}") |> Timex.to_unix() |> Kernel.+(valid_till)

    assert expire_time == Pleroma.Web.RichMedia.Parser.TTL.AwsSignedUrl.ttl(metadata, url)
  end

  test "s3 signed url is parsed and correct ttl is set for rich media" do
    url = "https://pleroma.social/amz"

    {:ok, timestamp} =
      Timex.now()
      |> DateTime.truncate(:second)
      |> Timex.format("{ISO:Basic:Z}")

    # in seconds
    valid_till = 30

    metadata = construct_metadata(timestamp, valid_till, url)

    body = """
    <meta name="twitter:card" content="Pleroma" />
    <meta name="twitter:site" content="Pleroma" />
    <meta name="twitter:title" content="Pleroma" />
    <meta name="twitter:description" content="Pleroma" />
    <meta name="twitter:image" content="#{Map.get(metadata, :image)}" />
    """

    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: "https://pleroma.social/amz"
      } ->
        %Tesla.Env{status: 200, body: body}
    end)

    Cachex.put(:rich_media_cache, url, metadata)

    Pleroma.Web.RichMedia.Parser.set_ttl_based_on_image({:ok, metadata}, url)

    {:ok, cache_ttl} = Cachex.ttl(:rich_media_cache, url)

    # as there is delay in setting and pulling the data from cache we ignore 1 second
    # make it 2 seconds for flakyness
    assert_in_delta(valid_till * 1000, cache_ttl, 2000)
  end

  defp construct_s3_url(timestamp, valid_till) do
    "https://pleroma.s3.ap-southeast-1.amazonaws.com/sachin%20%281%29%20_a%20-%25%2Aasdasd%20BNN%20bnnn%20.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIBLWWK6RGDQXDLJQ%2F20190716%2Fap-southeast-1%2Fs3%2Faws4_request&X-Amz-Date=#{
      timestamp
    }&X-Amz-Expires=#{valid_till}&X-Amz-Signature=04ffd6b98634f4b1bbabc62e0fac4879093cd54a6eed24fe8eb38e8369526bbf&X-Amz-SignedHeaders=host"
  end

  defp construct_metadata(timestamp, valid_till, url) do
    %{
      image: construct_s3_url(timestamp, valid_till),
      site: "Pleroma",
      title: "Pleroma",
      description: "Pleroma",
      url: url
    }
  end
end
