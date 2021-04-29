# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.ExAwsTest do
  use ExUnit.Case

  import Tesla.Mock
  alias Pleroma.HTTP

  @url "https://s3.amazonaws.com/test_bucket/test_image.jpg"

  setup do
    mock(fn
      %{method: :get, url: @url, headers: [{"x-amz-bucket-region", "us-east-1"}]} ->
        %Tesla.Env{
          status: 200,
          body: "image-content",
          headers: [{"x-amz-bucket-region", "us-east-1"}]
        }

      %{method: :post, url: @url, body: "image-content-2"} ->
        %Tesla.Env{status: 200, body: "image-content-2"}
    end)

    :ok
  end

  describe "request" do
    test "get" do
      assert HTTP.ExAws.request(:get, @url, "", [{"x-amz-bucket-region", "us-east-1"}]) == {
               :ok,
               %{
                 body: "image-content",
                 headers: [{"x-amz-bucket-region", "us-east-1"}],
                 status_code: 200
               }
             }
    end

    test "post" do
      assert HTTP.ExAws.request(:post, @url, "image-content-2", [
               {"x-amz-bucket-region", "us-east-1"}
             ]) == {
               :ok,
               %{
                 body: "image-content-2",
                 headers: [],
                 status_code: 200
               }
             }
    end
  end
end
