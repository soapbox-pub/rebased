# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.XmlBuilderTest do
  use Pleroma.DataCase
  alias Pleroma.XmlBuilder

  test "Build a basic xml string from a tuple" do
    data = {:feed, %{xmlns: "http://www.w3.org/2005/Atom"}, "Some content"}

    expected_xml = "<feed xmlns=\"http://www.w3.org/2005/Atom\">Some content</feed>"

    assert XmlBuilder.to_xml(data) == expected_xml
  end

  test "returns a complete document" do
    data = {:feed, %{xmlns: "http://www.w3.org/2005/Atom"}, "Some content"}

    expected_xml =
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?><feed xmlns=\"http://www.w3.org/2005/Atom\">Some content</feed>"

    assert XmlBuilder.to_doc(data) == expected_xml
  end

  test "Works without attributes" do
    data = {
      :feed,
      "Some content"
    }

    expected_xml = "<feed>Some content</feed>"

    assert XmlBuilder.to_xml(data) == expected_xml
  end

  test "It works with nested tuples" do
    data = {
      :feed,
      [
        {:guy, "brush"},
        {:lament, %{configuration: "puzzle"}, "pinhead"}
      ]
    }

    expected_xml =
      ~s[<feed><guy>brush</guy><lament configuration="puzzle">pinhead</lament></feed>]

    assert XmlBuilder.to_xml(data) == expected_xml
  end

  test "Represents NaiveDateTime as iso8601" do
    assert XmlBuilder.to_xml(~N[2000-01-01 13:13:33]) == "2000-01-01T13:13:33"
  end

  test "Uses self-closing tags when no content is giving" do
    data = {
      :link,
      %{rel: "self"}
    }

    expected_xml = ~s[<link rel="self" />]
    assert XmlBuilder.to_xml(data) == expected_xml
  end
end
