# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTMLTest do
  alias Pleroma.HTML
  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI
  use Pleroma.DataCase

  import Pleroma.Factory

  @html_sample """
    <b>this is in bold</b>
    <p>this is a paragraph</p>
    this is a linebreak<br />
    this is a link with allowed "rel" attribute: <a href="http://example.com/" rel="tag">example.com</a>
    this is a link with not allowed "rel" attribute: <a href="http://example.com/" rel="tag noallowed">example.com</a>
    this is an image: <img src="http://example.com/image.jpg"><br />
    <script>alert('hacked')</script>
  """

  @html_onerror_sample """
  <img src="http://example.com/image.jpg" onerror="alert('hacked')">
  """

  @html_span_class_sample """
  <span class="animate-spin">hi</span>
  """

  @html_span_microformats_sample """
  <span class="h-card"><a class="u-url mention">@<span>foo</span></a></span>
  """

  @html_span_invalid_microformats_sample """
  <span class="h-card"><a class="u-url mention animate-spin">@<span>foo</span></a></span>
  """

  describe "StripTags scrubber" do
    test "works as expected" do
      expected = """
        this is in bold
        this is a paragraph
        this is a linebreak
        this is a link with allowed &quot;rel&quot; attribute: example.com
        this is a link with not allowed &quot;rel&quot; attribute: example.com
        this is an image: 
        alert(&#39;hacked&#39;)
      """

      assert expected == HTML.strip_tags(@html_sample)
    end

    test "does not allow attribute-based XSS" do
      expected = "\n"

      assert expected == HTML.strip_tags(@html_onerror_sample)
    end
  end

  describe "TwitterText scrubber" do
    test "normalizes HTML as expected" do
      expected = """
        this is in bold
        <p>this is a paragraph</p>
        this is a linebreak<br/>
        this is a link with allowed &quot;rel&quot; attribute: <a href="http://example.com/" rel="tag">example.com</a>
        this is a link with not allowed &quot;rel&quot; attribute: <a href="http://example.com/">example.com</a>
        this is an image: <img src="http://example.com/image.jpg"/><br/>
        alert(&#39;hacked&#39;)
      """

      assert expected == HTML.filter_tags(@html_sample, Pleroma.HTML.Scrubber.TwitterText)
    end

    test "does not allow attribute-based XSS" do
      expected = """
      <img src="http://example.com/image.jpg"/>
      """

      assert expected == HTML.filter_tags(@html_onerror_sample, Pleroma.HTML.Scrubber.TwitterText)
    end

    test "does not allow spans with invalid classes" do
      expected = """
      <span>hi</span>
      """

      assert expected ==
               HTML.filter_tags(@html_span_class_sample, Pleroma.HTML.Scrubber.TwitterText)
    end

    test "does allow microformats" do
      expected = """
      <span class="h-card"><a class="u-url mention">@<span>foo</span></a></span>
      """

      assert expected ==
               HTML.filter_tags(@html_span_microformats_sample, Pleroma.HTML.Scrubber.TwitterText)
    end

    test "filters invalid microformats markup" do
      expected = """
      <span class="h-card"><a>@<span>foo</span></a></span>
      """

      assert expected ==
               HTML.filter_tags(
                 @html_span_invalid_microformats_sample,
                 Pleroma.HTML.Scrubber.TwitterText
               )
    end
  end

  describe "default scrubber" do
    test "normalizes HTML as expected" do
      expected = """
        <b>this is in bold</b>
        <p>this is a paragraph</p>
        this is a linebreak<br/>
        this is a link with allowed &quot;rel&quot; attribute: <a href="http://example.com/" rel="tag">example.com</a>
        this is a link with not allowed &quot;rel&quot; attribute: <a href="http://example.com/">example.com</a>
        this is an image: <img src="http://example.com/image.jpg"/><br/>
        alert(&#39;hacked&#39;)
      """

      assert expected == HTML.filter_tags(@html_sample, Pleroma.HTML.Scrubber.Default)
    end

    test "does not allow attribute-based XSS" do
      expected = """
      <img src="http://example.com/image.jpg"/>
      """

      assert expected == HTML.filter_tags(@html_onerror_sample, Pleroma.HTML.Scrubber.Default)
    end

    test "does not allow spans with invalid classes" do
      expected = """
      <span>hi</span>
      """

      assert expected == HTML.filter_tags(@html_span_class_sample, Pleroma.HTML.Scrubber.Default)
    end

    test "does allow microformats" do
      expected = """
      <span class="h-card"><a class="u-url mention">@<span>foo</span></a></span>
      """

      assert expected ==
               HTML.filter_tags(@html_span_microformats_sample, Pleroma.HTML.Scrubber.Default)
    end

    test "filters invalid microformats markup" do
      expected = """
      <span class="h-card"><a>@<span>foo</span></a></span>
      """

      assert expected ==
               HTML.filter_tags(
                 @html_span_invalid_microformats_sample,
                 Pleroma.HTML.Scrubber.Default
               )
    end
  end

  describe "extract_first_external_url" do
    test "extracts the url" do
      user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" =>
            "I think I just found the best github repo https://github.com/komeiji-satori/Dress"
        })

      object = Object.normalize(activity)
      {:ok, url} = HTML.extract_first_external_url(object, object.data["content"])
      assert url == "https://github.com/komeiji-satori/Dress"
    end

    test "skips mentions" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" =>
            "@#{other_user.nickname} install misskey! https://github.com/syuilo/misskey/blob/develop/docs/setup.en.md"
        })

      object = Object.normalize(activity)
      {:ok, url} = HTML.extract_first_external_url(object, object.data["content"])

      assert url == "https://github.com/syuilo/misskey/blob/develop/docs/setup.en.md"

      refute url == other_user.ap_id
    end

    test "skips hashtags" do
      user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" =>
            "#cofe https://www.pixiv.net/member_illust.php?mode=medium&illust_id=72255140"
        })

      object = Object.normalize(activity)
      {:ok, url} = HTML.extract_first_external_url(object, object.data["content"])

      assert url == "https://www.pixiv.net/member_illust.php?mode=medium&illust_id=72255140"
    end

    test "skips microformats hashtags" do
      user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" =>
            "<a href=\"https://pleroma.gov/tags/cofe\" rel=\"tag\">#cofe</a> https://www.pixiv.net/member_illust.php?mode=medium&illust_id=72255140",
          "content_type" => "text/html"
        })

      object = Object.normalize(activity)
      {:ok, url} = HTML.extract_first_external_url(object, object.data["content"])

      assert url == "https://www.pixiv.net/member_illust.php?mode=medium&illust_id=72255140"
    end

    test "does not crash when there is an HTML entity in a link" do
      user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{"status" => "\"http://cofe.com/?boomer=ok&foo=bar\""})

      object = Object.normalize(activity)

      assert {:ok, nil} = HTML.extract_first_external_url(object, object.data["content"])
    end
  end
end
