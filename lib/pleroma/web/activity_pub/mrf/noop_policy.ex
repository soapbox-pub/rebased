defmodule Pleroma.Web.ActivityPub.MRF.NoOpPolicy do
  def filter(object) do
    {:ok, object}
  end
end
