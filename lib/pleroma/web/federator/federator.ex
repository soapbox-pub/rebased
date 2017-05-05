defmodule Pleroma.Web.Federator do
  alias Pleroma.User
  alias Pleroma.Web.WebFinger
  require Logger

  @websub Application.get_env(:pleroma, :websub)

  def handle(:publish, activity) do
    Logger.debug(fn -> "Running publish for #{activity.data["id"]}" end)
    with actor when not is_nil(actor) <- User.get_cached_by_ap_id(activity.data["actor"]) do
      Logger.debug(fn -> "Sending #{activity.data["id"]} out via websub" end)
      Pleroma.Web.Websub.publish(Pleroma.Web.OStatus.feed_path(actor), actor, activity)

      {:ok, actor} = WebFinger.ensure_keys_present(actor)
      Logger.debug(fn -> "Sending #{activity.data["id"]} out via salmon" end)
      Pleroma.Web.Salmon.publish(actor, activity)
    end
  end

  def handle(:verify_websub, websub) do
    Logger.debug(fn -> "Running websub verification for #{websub.id} (#{websub.topic}, #{websub.callback})" end)
    @websub.verify(websub)
  end

  def handle(type, payload) do
    Logger.debug(fn -> "Unknown task: #{type}" end)
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
