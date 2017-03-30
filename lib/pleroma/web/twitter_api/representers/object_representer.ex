defmodule Pleroma.Web.TwitterAPI.Representers.ObjectRepresenter do
  use Pleroma.Web.TwitterAPI.Representers.BaseRepresenter
  alias Pleroma.Object

  def to_map(%Object{} = object, _opts) do
    data = object.data
    url = List.first(data["url"])
    %{
      url: url["href"],
      mimetype: url["mediaType"],
      id: object.id,
      oembed: false
    }
  end
end
