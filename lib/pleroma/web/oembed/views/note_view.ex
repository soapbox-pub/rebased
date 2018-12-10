defmodule Pleroma.Web.OEmbed.NoteView do
  use Pleroma.Web, :view
  alias Pleroma.{User, Activity}
  alias Pleroma.Web.OEmbed

  def render("note.json", %{type: type, entity: activity }) do
    oembed_data(activity)
  end

  def oembed_data(activity) do
    with %User{} = user <- User.get_cached_by_ap_id(activity.data["actor"]),
         image = User.avatar_url(user) |> MediaProxy.url() do
      %{
        version: "1.0",
        type: "link",
        title: OEmbed.truncated_content(activity),
        provider_url: "https://pleroma.site",
        thumbnail_url: image,
      }
  end
end
