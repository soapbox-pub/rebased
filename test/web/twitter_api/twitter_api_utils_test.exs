defmodule Pleroma.Web.TwitterAPI.UtilsTest do
  alias Pleroma.Web.TwitterAPI.Utils
  use Pleroma.DataCase

  test "it adds attachment links to a given text and attachment set" do
    attachment = %{
      "url" => [%{"href" => "http://heise.de/i\"m a boy.png"}]
    }

    res = Utils.add_attachments("", [attachment])

    assert res == "<br>\n<a href=\"http://heise.de/i\"m a boy.png\" class='attachment'>i\"m a boy.png</a>"
  end
end
