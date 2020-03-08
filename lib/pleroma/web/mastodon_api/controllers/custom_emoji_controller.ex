# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.CustomEmojiController do
  use Pleroma.Web, :controller

  def index(conn, _params) do
    render(conn, "index.json", custom_emojis: Pleroma.Emoji.get_all())
  end
end
