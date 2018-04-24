defmodule Pleroma.Web.ActivityPub.MRF.DropPolicy do
  require Logger

  def filter(object) do
    Logger.info("REJECTING #{inspect(object)}")
    {:reject, object}
  end
end
