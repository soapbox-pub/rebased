# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.WebPushHttpClientMock do
  def get(url, headers \\ [], options \\ []) do
    {
      res,
      %Tesla.Env{status: status}
    } = Pleroma.HTTP.request(:get, url, "", headers, options)

    {res, %{status_code: status}}
  end

  def post(url, body, headers \\ [], options \\ []) do
    {
      res,
      %Tesla.Env{status: status}
    } = Pleroma.HTTP.request(:post, url, body, headers, options)

    {res, %{status_code: status}}
  end
end
