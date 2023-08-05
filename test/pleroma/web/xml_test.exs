defmodule Pleroma.Web.XMLTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.XML

  test "refuses to load external entities from XML" do
    data = File.read!("test/fixtures/xml_external_entities.xml")
    assert(:error == XML.parse_document(data))
  end
end
