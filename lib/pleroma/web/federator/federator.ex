defmodule Pleroma.Web.Federator do
  use GenServer
  alias Pleroma.User
  alias Pleroma.Activity
  alias Pleroma.Web.{WebFinger, Websub}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Transmogrifier
  require Logger

  @websub Application.get_env(:pleroma, :websub)
  @ostatus Application.get_env(:pleroma, :ostatus)
  @httpoison Application.get_env(:pleroma, :httpoison)
  @instance Application.get_env(:pleroma, :instance)
  @federating Keyword.get(@instance, :federating)
  @max_jobs 20

  def start_link do
    spawn(fn ->
      Process.sleep(1000 * 60 * 1) # 1 minute
      enqueue(:refresh_subscriptions, nil)
    end)
    GenServer.start_link(__MODULE__, %{
          in: {:sets.new(), []},
          out: {:sets.new(), []}
                         }, name: __MODULE__)
  end

  def handle(:refresh_subscriptions, _) do
    Logger.debug("Federator running refresh subscriptions")
    Websub.refresh_subscriptions()
    spawn(fn ->
      Process.sleep(1000 * 60 * 60 * 6) # 6 hours
      enqueue(:refresh_subscriptions, nil)
    end)
  end

  def handle(:request_subscription, websub) do
    Logger.debug("Refreshing #{websub.topic}")
    with {:ok, websub } <- Websub.request_subscription(websub) do
      Logger.debug("Successfully refreshed #{websub.topic}")
    else
      _e -> Logger.debug("Couldn't refresh #{websub.topic}")
    end
  end

  def handle(:publish, activity) do
    Logger.debug(fn -> "Running publish for #{activity.data["id"]}" end)
    with actor when not is_nil(actor) <- User.get_cached_by_ap_id(activity.data["actor"]) do
      {:ok, actor} = WebFinger.ensure_keys_present(actor)
      if ActivityPub.is_public?(activity) do
        Logger.info(fn -> "Sending #{activity.data["id"]} out via WebSub" end)
        Websub.publish(Pleroma.Web.OStatus.feed_path(actor), actor, activity)

        Logger.info(fn -> "Sending #{activity.data["id"]} out via Salmon" end)
        Pleroma.Web.Salmon.publish(actor, activity)
      end

      Logger.info(fn -> "Sending #{activity.data["id"]} out via AP" end)
      Pleroma.Web.ActivityPub.ActivityPub.publish(actor, activity)
    end
  end

  def handle(:verify_websub, websub) do
    Logger.debug(fn -> "Running WebSub verification for #{websub.id} (#{websub.topic}, #{websub.callback})" end)
    @websub.verify(websub)
  end

  def handle(:incoming_doc, doc) do
    Logger.info("Got document, trying to parse")
    @ostatus.handle_incoming(doc)
  end

  def handle(:incoming_ap_doc, params) do
    Logger.info("Handling incoming AP activity")
    with {:ok, _user} <- ap_enabled_actor(params["actor"]),
         nil <- Activity.get_by_ap_id(params["id"]),
         {:ok, activity} <- Transmogrifier.handle_incoming(params) do
    else
      %Activity{} ->
        Logger.info("Already had #{params["id"]}")
      e ->
        # Just drop those for now
        Logger.info("Unhandled activity")
        Logger.info(Poison.encode!(params, [pretty: 2]))
    end
  end

  def handle(:publish_single_ap, params) do
    ActivityPub.publish_one(params)
  end

  def handle(:publish_single_websub, %{xml: xml, topic: topic, callback: callback, secret: secret}) do
    signature = @websub.sign(secret || "", xml)
    Logger.debug(fn -> "Pushing #{topic} to #{callback}" end)

    with {:ok, %{status_code: code}} <- @httpoison.post(callback, xml, [
                  {"Content-Type", "application/atom+xml"},
                  {"X-Hub-Signature", "sha1=#{signature}"}
                ], timeout: 10000, recv_timeout: 20000, hackney: [pool: :default]) do
      Logger.debug(fn -> "Pushed to #{callback}, code #{code}" end)
    else e ->
        Logger.debug(fn -> "Couldn't push to #{callback}, #{inspect(e)}" end)
    end
  end

  def handle(type, _) do
    Logger.debug(fn -> "Unknown task: #{type}" end)
    {:error, "Don't know what to do with this"}
  end

  def enqueue(type, payload, priority \\ 1) do
    if @federating do
      if Mix.env == :test do
        handle(type, payload)
      else
        GenServer.cast(__MODULE__, {:enqueue, type, payload, priority})
      end
    end
  end

  def maybe_start_job(running_jobs, queue) do
    if (:sets.size(running_jobs) < @max_jobs) && queue != [] do
      {{type, payload}, queue} = queue_pop(queue)
      {:ok, pid} = Task.start(fn -> handle(type, payload) end)
      mref = Process.monitor(pid)
      {:sets.add_element(mref, running_jobs), queue}
    else
      {running_jobs, queue}
    end
  end

  def handle_cast({:enqueue, type, payload, priority}, state) when type in [:incoming_doc, :incoming_ap_doc] do
    %{in: {i_running_jobs, i_queue}, out: {o_running_jobs, o_queue}} = state
    i_queue = enqueue_sorted(i_queue, {type, payload}, 1)
    {i_running_jobs, i_queue} = maybe_start_job(i_running_jobs, i_queue)
    {:noreply, %{in: {i_running_jobs, i_queue}, out: {o_running_jobs, o_queue}}}
  end

  def handle_cast({:enqueue, type, payload, priority}, state) do
    %{in: {i_running_jobs, i_queue}, out: {o_running_jobs, o_queue}} = state
    o_queue = enqueue_sorted(o_queue, {type, payload}, 1)
    {o_running_jobs, o_queue} = maybe_start_job(o_running_jobs, o_queue)
    {:noreply, %{in: {i_running_jobs, i_queue}, out: {o_running_jobs, o_queue}}}
  end

  def handle_cast(m, state) do
    IO.inspect("Unknown: #{inspect(m)}, #{inspect(state)}")
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    %{in: {i_running_jobs, i_queue}, out: {o_running_jobs, o_queue}} = state
    i_running_jobs = :sets.del_element(ref, i_running_jobs)
    o_running_jobs = :sets.del_element(ref, o_running_jobs)
    {i_running_jobs, i_queue} = maybe_start_job(i_running_jobs, i_queue)
    {o_running_jobs, o_queue} = maybe_start_job(o_running_jobs, o_queue)

    {:noreply, %{in: {i_running_jobs, i_queue}, out: {o_running_jobs, o_queue}}}
  end

  def enqueue_sorted(queue, element, priority) do
    [%{item: element, priority: priority} | queue]
    |> Enum.sort_by(fn (%{priority: priority}) -> priority end)
  end

  def queue_pop([%{item: element} | queue]) do
    {element, queue}
  end

  def ap_enabled_actor(id) do
    user = User.get_by_ap_id(id)
    if User.ap_enabled?(user) do
      {:ok, user}
    else
      ActivityPub.make_user_from_ap_id(id)
    end
  end
end
