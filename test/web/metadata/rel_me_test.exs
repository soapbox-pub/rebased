# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.RelMeTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Web.Metadata.Providers.RelMe

  test "it renders all links with rel='me' from user bio" do
    bio =
      ~s(<a href="https://some-link.com">https://some-link.com</a> <a rel="me" href="https://another-link.com">https://another-link.com</a>
    <link href="http://some.com"> <link rel="me" href="http://some3.com>")

    user = insert(:user, %{bio: bio})

    assert RelMe.build_tags(%{user: user}) == [
             {:link, [rel: "me", href: "http://some3.com>"], []},
             {:link, [rel: "me", href: "https://another-link.com"], []}
           ]
  end
end
