defmodule Pleroma.Web.TwitterAPI.Representers.ObjectRepresenter do
  use Pleroma.Web.TwitterAPI.Representers.BaseRepresenter
  alias Pleroma.Object

  def to_map(%Object{} = object, _opts) do
    data = object.data
    url = List.first(data["url"])
    %{
      url: url["href"] |> Pleroma.Web.MediaProxy.url(),
      mimetype: url["mediaType"],
      id: data["uuid"],
      oembed: false
    }
  end

  # If we only get the naked data, wrap in an object
  def to_map(%{} = data, opts) do
    to_map(%Object{data: data}, opts)
  end
end
