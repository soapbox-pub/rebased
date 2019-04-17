# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTMLTest do
  alias Pleroma.HTML
  use Pleroma.DataCase

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

  describe "StripTags scrubber" do
    test "works as expected" do
      expected = """
      this is in bold
        this is a paragraph
        this is a linebreak
        this is a link with allowed "rel" attribute: example.com
        this is a link with not allowed "rel" attribute: example.com
        this is an image: 
        alert('hacked')
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
        this is a linebreak<br />
        this is a link with allowed "rel" attribute: <a href="http://example.com/" rel="tag">example.com</a>
        this is a link with not allowed "rel" attribute: <a href="http://example.com/">example.com</a>
        this is an image: <img src="http://example.com/image.jpg" /><br />
        alert('hacked')
      """

      assert expected == HTML.filter_tags(@html_sample, Pleroma.HTML.Scrubber.TwitterText)
    end

    test "does not allow attribute-based XSS" do
      expected = """
      <img src="http://example.com/image.jpg" />
      """

      assert expected == HTML.filter_tags(@html_onerror_sample, Pleroma.HTML.Scrubber.TwitterText)
    end
  end

  describe "default scrubber" do
    test "normalizes HTML as expected" do
      expected = """
      <b>this is in bold</b>
        <p>this is a paragraph</p>
        this is a linebreak<br />
        this is a link with allowed "rel" attribute: <a href="http://example.com/" rel="tag">example.com</a>
        this is a link with not allowed "rel" attribute: <a href="http://example.com/">example.com</a>
        this is an image: <img src="http://example.com/image.jpg" /><br />
        alert('hacked')
      """

      assert expected == HTML.filter_tags(@html_sample, Pleroma.HTML.Scrubber.Default)
    end

    test "does not allow attribute-based XSS" do
      expected = """
      <img src="http://example.com/image.jpg" />
      """

      assert expected == HTML.filter_tags(@html_onerror_sample, Pleroma.HTML.Scrubber.Default)
    end
  end
end
