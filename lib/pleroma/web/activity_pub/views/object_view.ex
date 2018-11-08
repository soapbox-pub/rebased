defmodule Pleroma.Web.ActivityPub.ObjectView do
  use Pleroma.Web, :view
  alias Pleroma.Web.ActivityPub.Transmogrifier

  def render("object.json", %{object: object}) do
    base = Pleroma.Web.ActivityPub.Utils.make_json_ld_header()

    additional = Transmogrifier.prepare_object(object.data)
    Map.merge(base, additional)
  end
end
