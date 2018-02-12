defmodule Pleroma.Web.OStatusMock do
  import Pleroma.Factory
  def handle_incoming(_doc) do
    insert(:note_activity)
  end
end
