# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NormalizeMarkupTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.MRF.NormalizeMarkup

  @html_sample """
  <b>this is in bold</b>
  <p>this is a paragraph</p>
  this is a linebreak<br />
  this is a link with allowed "rel" attribute: <a href="http://example.com/" rel="tag">example.com</a>
  this is a link with not allowed "rel" attribute: <a href="http://example.com/" rel="tag noallowed">example.com</a>
  this is an image: <img src="http://example.com/image.jpg"><br />
  <script>alert('hacked')</script>
  """

  test "it filter html tags" do
    expected = """
    <b>this is in bold</b>
    <p>this is a paragraph</p>
    this is a linebreak<br/>
    this is a link with allowed &quot;rel&quot; attribute: <a href="http://example.com/" rel="tag">example.com</a>
    this is a link with not allowed &quot;rel&quot; attribute: <a href="http://example.com/">example.com</a>
    this is an image: <img src="http://example.com/image.jpg"/><br/>
    alert(&#39;hacked&#39;)
    """

    message = %{"type" => "Create", "object" => %{"content" => @html_sample}}

    assert {:ok, res} = NormalizeMarkup.filter(message)
    assert res["object"]["content"] == expected
  end

  test "it skips filter if type isn't `Create`" do
    message = %{"type" => "Note", "object" => %{}}

    assert {:ok, res} = NormalizeMarkup.filter(message)
    assert res == message
  end
end
