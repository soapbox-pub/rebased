defmodule Pleroma.Web.Federator do
  use GenServer
  alias Pleroma.User
  alias Pleroma.Web.{WebFinger, Websub}
  require Logger

  @websub Application.get_env(:pleroma, :websub)
  @ostatus Application.get_env(:pleroma, :ostatus)
  @httpoison Application.get_env(:pleroma, :httpoison)
  @max_jobs 10

  def start_link do
    spawn(fn ->
      Process.sleep(1000 * 60 * 1) # 1 minute
      enqueue(:refresh_subscriptions, nil)
    end)
    GenServer.start_link(__MODULE__, {:sets.new(), :queue.new()}, name: __MODULE__)
  end

  def handle(:refresh_subscriptions, _) do
    Logger.debug("Federator running refresh subscriptions")
    Websub.refresh_subscriptions()
    spawn(fn ->
      Process.sleep(1000 * 60 * 60 * 6) # 6 hours
      enqueue(:refresh_subscriptions, nil)
    end)
  end

  def handle(:publish, activity) do
    Logger.debug(fn -> "Running publish for #{activity.data["id"]}" end)
    with actor when not is_nil(actor) <- User.get_cached_by_ap_id(activity.data["actor"]) do
      Logger.debug(fn -> "Sending #{activity.data["id"]} out via websub" end)
      Websub.publish(Pleroma.Web.OStatus.feed_path(actor), actor, activity)

      {:ok, actor} = WebFinger.ensure_keys_present(actor)
      Logger.debug(fn -> "Sending #{activity.data["id"]} out via salmon" end)
      Pleroma.Web.Salmon.publish(actor, activity)
    end
  end

  def handle(:verify_websub, websub) do
    Logger.debug(fn -> "Running websub verification for #{websub.id} (#{websub.topic}, #{websub.callback})" end)
    @websub.verify(websub)
  end

  def handle(:incoming_doc, doc) do
    Logger.debug("Got document, trying to parse")
    @ostatus.handle_incoming(doc)
  end

  def handle(:publish_single_websub, %{xml: xml, topic: topic, callback: callback, secret: secret}) do
    signature = @websub.sign(secret || "", xml)
    Logger.debug(fn -> "Pushing #{topic} to #{callback}" end)

    with {:ok, %{status_code: code}} <- @httpoison.post(callback, xml, [
                  {"Content-Type", "application/atom+xml"},
                  {"X-Hub-Signature", "sha1=#{signature}"}
                ], timeout: 10000, recv_timeout: 20000) do
      Logger.debug(fn -> "Pushed to #{callback}, code #{code}" end)
    else e ->
        Logger.debug(fn -> "Couldn't push to #{callback}, #{inspect(e)}" end)
    end
  end

  def handle(type, payload) do
    Logger.debug(fn -> "Unknown task: #{type}" end)
    {:error, "Don't know what do do with this"}
  end

  def enqueue(type, payload) do
    if Mix.env == :test do
      handle(type, payload)
    else
      GenServer.cast(__MODULE__, {:enqueue, type, payload})
    end
  end

  def maybe_start_job(running_jobs, queue) do
    if (:sets.size(running_jobs) < @max_jobs) && !:queue.is_empty(queue) do
      {{:value, {type, payload}}, queue} = :queue.out(queue)
      {:ok, pid} = Task.start(fn -> handle(type, payload) end)
      mref = Process.monitor(pid)
      {:sets.add_element(mref, running_jobs), queue}
    else
      {running_jobs, queue}
    end
  end

  def handle_cast({:enqueue, type, payload}, {running_jobs, queue}) do
    queue = :queue.in({type, payload}, queue)
    {running_jobs, queue} = maybe_start_job(running_jobs, queue)
    {:noreply, {running_jobs, queue}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, {running_jobs, queue}) do
    running_jobs = :sets.del_element(ref, running_jobs)
    {running_jobs, queue} = maybe_start_job(running_jobs, queue)
    {:noreply, {running_jobs, queue}}
  end

  def handle_cast(m, state) do
    IO.inspect("Unknown: #{inspect(m)}, #{inspect(state)}")
    {:noreply, state}
  end
end
