# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.MediaProxyCacheView do
  use Pleroma.Web, :view

  def render("index.json", %{urls: urls, page_size: page_size, count: count}) do
    %{
      urls: urls,
      count: count,
      page_size: page_size
    }
  end
end
