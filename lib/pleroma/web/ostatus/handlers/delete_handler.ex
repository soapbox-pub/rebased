defmodule Pleroma.Web.OStatus.DeleteHandler do
  require Logger
  alias Pleroma.Web.XML
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.ActivityPub

  def handle_delete(entry, _doc \\ nil) do
    with id <- XML.string_from_xpath("//id", entry),
         %Object{} = object <- Object.normalize(id),
         {:ok, delete} <- ActivityPub.delete(object, false) do
      delete
    end
  end
end
