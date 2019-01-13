# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OStatusMock do
  import Pleroma.Factory

  def handle_incoming(_doc) do
    insert(:note_activity)
  end
end
