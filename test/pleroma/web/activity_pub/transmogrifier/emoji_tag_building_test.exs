defmodule Pleroma.Web.ActivityPub.Transmogrifier.EmojiTagBuildingTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.Transmogrifier

  test "it encodes the id to be a valid url" do
    name = "hanapog"
    url = "https://misskey.local.live/emojis/hana pog.png"

    tag = Transmogrifier.build_emoji_tag({name, url})

    assert tag["id"] == "https://misskey.local.live/emojis/hana%20pog.png"
  end
end
