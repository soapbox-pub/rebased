defmodule Pleroma.Web.OStatus.DeleteHandler do
  require Logger
  alias Pleroma.Web.{XML, OStatus}
  alias Pleroma.{Activity, Object, Repo}

  def handle_delete(entry, doc \\ nil) do
    with id <- XML.string_from_xpath("//id", entry),
         object when not is_nil(object) <- Object.get_by_ap_id(id) do
      Repo.delete(object)
      Repo.delete_all(Activity.all_by_object_ap_id_q(id))
      nil
    end
  end
end
