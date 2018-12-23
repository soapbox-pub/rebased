defmodule Pleroma.Web.ActivityPub.MRF.HellthreadPolicy do
  @behaviour Pleroma.Web.ActivityPub.MRF

  @impl true
  def filter(%{"type" => "Create"} = object) do
    threshold = Pleroma.Config.get([:mrf_hellthread, :threshold])
    recipients = (object["to"] || []) ++ (object["cc"] || [])

    if length(recipients) > threshold do
      {:reject, nil}
    else
      {:ok, object}
    end
  end

  @impl true
  def filter(object), do: {:ok, object}
end
