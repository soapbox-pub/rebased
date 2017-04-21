defmodule Pleroma.Web.Websub do
  alias Pleroma.Repo

  def verify(subscription, getter \\ &HTTPoison.get/3 ) do
    challenge = Base.encode16(:crypto.strong_rand_bytes(8))
    lease_seconds = NaiveDateTime.diff(subscription.inserted_at, subscription.valid_until)
    with {:ok, response} <- getter.(subscription.callback, [], [params: %{
                                                              "hub.challenge": challenge,
                                                              "hub.lease_seconds": lease_seconds,
                                                              "hub.topic": subscription.topic,
                                                              "hub.mode": "subscribe"
                                                                }]),
         ^challenge <- response.body
    do
      changeset = Ecto.Changeset.change(subscription, %{state: "active"})
      Repo.update(changeset)
    else _e ->
      changeset = Ecto.Changeset.change(subscription, %{state: "rejected"})
      {:ok, subscription } = Repo.update(changeset)
      {:error, subscription}
    end
  end
end
