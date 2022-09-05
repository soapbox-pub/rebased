# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NormalizeMarkupTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.Web.ActivityPub.MRF
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

  @expected """
  <b>this is in bold</b>
  <p>this is a paragraph</p>
  this is a linebreak<br/>
  this is a link with allowed &quot;rel&quot; attribute: <a href="http://example.com/" rel="tag">example.com</a>
  this is a link with not allowed &quot;rel&quot; attribute: <a href="http://example.com/">example.com</a>
  this is an image: <img src="http://example.com/image.jpg"/><br/>
  alert(&#39;hacked&#39;)
  """

  test "it filter html tags" do
    message = %{"type" => "Create", "object" => %{"content" => @html_sample}}

    assert {:ok, res} = NormalizeMarkup.filter(message)
    assert res["object"]["content"] == @expected
  end

  test "history-aware" do
    message = %{
      "type" => "Create",
      "object" => %{
        "content" => @html_sample,
        "formerRepresentations" => %{"orderedItems" => [%{"content" => @html_sample}]}
      }
    }

    assert {:ok, res} = MRF.filter_one(NormalizeMarkup, message)

    assert %{
             "content" => @expected,
             "formerRepresentations" => %{"orderedItems" => [%{"content" => @expected}]}
           } = res["object"]
  end

  test "works with Updates" do
    message = %{
      "type" => "Update",
      "object" => %{
        "content" => @html_sample,
        "formerRepresentations" => %{"orderedItems" => [%{"content" => @html_sample}]}
      }
    }

    assert {:ok, res} = MRF.filter_one(NormalizeMarkup, message)

    assert %{
             "content" => @expected,
             "formerRepresentations" => %{"orderedItems" => [%{"content" => @expected}]}
           } = res["object"]
  end

  test "it skips filter if type isn't `Create` or `Update`" do
    message = %{"type" => "Note", "object" => %{}}

    assert {:ok, res} = NormalizeMarkup.filter(message)
    assert res == message
  end
end
