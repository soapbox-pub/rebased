# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.TTL.AwsSignedUrlTest do
  use ExUnit.Case, async: true

  test "amazon signed url is parsed and correct ttl is set for rich media" do
    url = "https://pleroma.social/amz"

    {:ok, timestamp} =
      Timex.now()
      |> DateTime.truncate(:second)
      |> Timex.format("{ISO:Basic:Z}")

    # in seconds
    valid_till = 30

    data = %{
      image:
        "https://pleroma.s3.ap-southeast-1.amazonaws.com/sachin%20%281%29%20_a%20-%25%2Aasdasd%20BNN%20bnnn%20.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIBLWWK6RGDQXDLJQ%2F20190716%2Fap-southeast-1%2Fs3%2Faws4_request&X-Amz-Date=#{
          timestamp
        }&X-Amz-Expires=#{valid_till}&X-Amz-Signature=04ffd6b98634f4b1bbabc62e0fac4879093cd54a6eed24fe8eb38e8369526bbf&X-Amz-SignedHeaders=host",
      locale: "en_US",
      site_name: "Pleroma",
      title: "PLeroma",
      url: url
    }

    Cachex.put(:rich_media_cache, url, data)
    assert {:ok, _} = Pleroma.Web.RichMedia.Parser.TTL.AwsSignedUrl.run(data, url)
    {:ok, cache_ttl} = Cachex.ttl(:rich_media_cache, url)

    # as there is delay in setting and pulling the data from cache we ignore 1 second
    assert_in_delta(valid_till * 1000, cache_ttl, 1000)
  end
end
