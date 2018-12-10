defmodule Pleroma.Web.OEmbed.OEmbedController do
  use Pleroma.Web, :controller

  alias Pleroma.Web.OEmbed
  alias Pleroma.Web.OEmbed.{NoteView, ActivityRepresenter}
  alias Pleroma.Web.MediaProxy
  alias Pleroma.Repo
  alias Pleroma.User

  def url(conn, %{ "url" => url} ) do
    case format = get_format(conn) do
      _ ->
        result = OEmbed.recognize_path(url)
        render_oembed(conn, format, result)
    end
  end

  def render_oembed(conn, format \\ "json", result)
  def render_oembed(conn, "json", result) do
    conn
    |> put_resp_content_type("application/json")
    |> json(NoteView.render("note.json", result))
  end

  def render_oembed(conn, "xml", result) do
    conn
    |> put_resp_content_type("application/xml")
    |> NoteView.render("note.json", result)

  end
end
