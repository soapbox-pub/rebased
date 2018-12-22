defmodule Pleroma.Web.ActivityPub.MRF.HellthreadPolicy do
  @behaviour Pleroma.Web.ActivityPub.MRF

  @impl true
  def filter(object) do

    policy = Pleroma.Config.get(:mrf_hellthreadmitigation)

    if (length(object["to"]) + length(object["cc"])) > Keyword.get(policy, :threshold) do
      {:reject, nil}
    else
      {:ok, object}
    end
  end
end