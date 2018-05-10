defmodule Pleroma.Web.ActivityPub.MRF.DropPolicy do
  require Logger
  @behaviour Pleroma.Web.ActivityPub.MRF

  @impl true
  def filter(object) do
    Logger.info("REJECTING #{inspect(object)}")
    {:reject, object}
  end
end
