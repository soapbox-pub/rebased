# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.RelMeTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory
  alias Pleroma.Web.Metadata.Providers.RelMe

  test "it renders all links with rel='me' from user bio" do
    bio =
      ~s(<a href="https://some-link.com">https://some-link.com</a> <a rel="me" href="https://another-link.com">https://another-link.com</a> <link href="http://some.com"> <link rel="me" href="http://some3.com">)

    fields = [
      %{
        "name" => "profile",
        "value" => ~S(<a rel="me" href="http://profile.com">http://profile.com</a>)
      },
      %{
        "name" => "like",
        "value" => ~S(<a href="http://cofe.io">http://cofe.io</a>)
      },
      %{"name" => "foo", "value" => "bar"}
    ]

    user = insert(:user, %{bio: bio, fields: fields})

    assert RelMe.build_tags(%{user: user}) == [
             {:link, [rel: "me", href: "http://some3.com"], []},
             {:link, [rel: "me", href: "https://another-link.com"], []},
             {:link, [rel: "me", href: "http://profile.com"], []}
           ]
  end
end
