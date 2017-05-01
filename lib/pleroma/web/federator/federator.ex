defmodule Pleroma.Web.Federator do
  alias Pleroma.User
  require Logger

  @websub Application.get_env(:pleroma, :websub)

  def handle(:publish, activity) do
    Logger.debug("Running publish for #{activity.data["id"]}")
    with actor when not is_nil(actor) <- User.get_cached_by_ap_id(activity.data["actor"]) do
      Logger.debug("Sending #{activity.data["id"]} out via websub")
      Pleroma.Web.Websub.publish(Pleroma.Web.OStatus.feed_path(actor), actor, activity)

      Logger.debug("Sending #{activity.data["id"]} out via salmon")
      Pleroma.Web.Salmon.publish(actor, activity)
    end
  end

  def handle(:verify_websub, websub) do
    Logger.debug("Running websub verification for #{websub.id} (#{websub.topic}, #{websub.callback})")
    @websub.verify(websub)
  end

  def handle(type, payload) do
    Logger.debug("Unknown task: #{type}")
    {:error, "Don't know what do do with this"}
  end

  def enqueue(type, payload) do
    # for now, just run immediately in a new process.
    if Mix.env == :test do
      handle(type, payload)
    else
      spawn(fn -> handle(type, payload) end)
    end
  end
end
