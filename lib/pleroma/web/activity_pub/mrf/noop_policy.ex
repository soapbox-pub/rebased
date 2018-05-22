defmodule Pleroma.Web.ActivityPub.MRF.NoOpPolicy do
  @behaviour Pleroma.Web.ActivityPub.MRF

  @impl true
  def filter(object) do
    {:ok, object}
  end
end
