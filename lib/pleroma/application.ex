# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Application do
  use Application

  @name Mix.Project.config()[:name]
  @version Mix.Project.config()[:version]
  @repository Mix.Project.config()[:source_url]
  def name, do: @name
  def version, do: @version
  def named_version, do: @name <> " " <> @version
  def repository, do: @repository

  def user_agent do
    info = "#{Pleroma.Web.base_url()} <#{Pleroma.Config.get([:instance, :email], "")}>"
    named_version() <> "; " <> info
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Cachex.Spec

    Pleroma.Config.DeprecationWarnings.warn()
    setup_instrumenters()

    # Define workers and child supervisors to be supervised
    children =
      [
        # Start the Ecto repository
        %{id: Pleroma.Repo, start: {Pleroma.Repo, :start_link, []}, type: :supervisor},
        %{id: Pleroma.Config.TransferTask, start: {Pleroma.Config.TransferTask, :start_link, []}},
        %{id: Pleroma.Emoji, start: {Pleroma.Emoji, :start_link, []}},
        %{id: Pleroma.Captcha, start: {Pleroma.Captcha, :start_link, []}},
        %{
          id: :cachex_used_captcha_cache,
          start:
            {Cachex, :start_link,
             [
               :used_captcha_cache,
               [
                 ttl_interval:
                   :timer.seconds(Pleroma.Config.get!([Pleroma.Captcha, :seconds_valid]))
               ]
             ]}
        },
        %{
          id: :cachex_user,
          start:
            {Cachex, :start_link,
             [
               :user_cache,
               [
                 default_ttl: 25_000,
                 ttl_interval: 1000,
                 limit: 2500
               ]
             ]}
        },
        %{
          id: :cachex_object,
          start:
            {Cachex, :start_link,
             [
               :object_cache,
               [
                 default_ttl: 25_000,
                 ttl_interval: 1000,
                 limit: 2500
               ]
             ]}
        },
        %{
          id: :cachex_rich_media,
          start:
            {Cachex, :start_link,
             [
               :rich_media_cache,
               [
                 default_ttl: :timer.minutes(120),
                 limit: 5000
               ]
             ]}
        },
        %{
          id: :cachex_scrubber,
          start:
            {Cachex, :start_link,
             [
               :scrubber_cache,
               [
                 limit: 2500
               ]
             ]}
        },
        %{
          id: :cachex_idem,
          start:
            {Cachex, :start_link,
             [
               :idempotency_cache,
               [
                 expiration:
                   expiration(
                     default: :timer.seconds(6 * 60 * 60),
                     interval: :timer.seconds(60)
                   ),
                 limit: 2500
               ]
             ]}
        },
        %{id: Pleroma.FlakeId, start: {Pleroma.FlakeId, :start_link, []}},
        %{
          id: Pleroma.ScheduledActivityWorker,
          start: {Pleroma.ScheduledActivityWorker, :start_link, []}
        }
      ] ++
        hackney_pool_children() ++
        [
          %{
            id: Pleroma.Web.Federator.RetryQueue,
            start: {Pleroma.Web.Federator.RetryQueue, :start_link, []}
          },
          %{
            id: Pleroma.Web.OAuth.Token.CleanWorker,
            start: {Pleroma.Web.OAuth.Token.CleanWorker, :start_link, []}
          },
          %{
            id: Pleroma.Stats,
            start: {Pleroma.Stats, :start_link, []}
          },
          %{
            id: :web_push_init,
            start: {Task, :start_link, [&Pleroma.Web.Push.init/0]},
            restart: :temporary
          },
          %{
            id: :federator_init,
            start: {Task, :start_link, [&Pleroma.Web.Federator.init/0]},
            restart: :temporary
          },
          %{
            id: :internal_fetch_init,
            start: {Task, :start_link, [&Pleroma.Web.ActivityPub.InternalFetchActor.init/0]},
            restart: :temporary
          }
        ] ++
        streamer_child() ++
        chat_child() ++
        [
          # Start the endpoint when the application starts
          %{
            id: Pleroma.Web.Endpoint,
            start: {Pleroma.Web.Endpoint, :start_link, []},
            type: :supervisor
          },
          %{id: Pleroma.Gopher.Server, start: {Pleroma.Gopher.Server, :start_link, []}}
        ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pleroma.Supervisor]
    result = Supervisor.start_link(children, opts)
    :ok = after_supervisor_start()
    result
  end

  defp setup_instrumenters do
    require Prometheus.Registry

    if Application.get_env(:prometheus, Pleroma.Repo.Instrumenter) do
      :ok =
        :telemetry.attach(
          "prometheus-ecto",
          [:pleroma, :repo, :query],
          &Pleroma.Repo.Instrumenter.handle_event/4,
          %{}
        )

      Pleroma.Repo.Instrumenter.setup()
    end

    Pleroma.Web.Endpoint.MetricsExporter.setup()
    Pleroma.Web.Endpoint.PipelineInstrumenter.setup()
    Pleroma.Web.Endpoint.Instrumenter.setup()
  end

  def enabled_hackney_pools do
    [:media] ++
      if Application.get_env(:tesla, :adapter) == Tesla.Adapter.Hackney do
        [:federation]
      else
        []
      end ++
      if Pleroma.Config.get([Pleroma.Upload, :proxy_remote]) do
        [:upload]
      else
        []
      end
  end

  if Pleroma.Config.get(:env) == :test do
    defp streamer_child, do: []
    defp chat_child, do: []
  else
    defp streamer_child do
      [%{id: Pleroma.Web.Streamer, start: {Pleroma.Web.Streamer, :start_link, []}}]
    end

    defp chat_child do
      if Pleroma.Config.get([:chat, :enabled]) do
        [
          %{
            id: Pleroma.Web.ChatChannel.ChatChannelState,
            start: {Pleroma.Web.ChatChannel.ChatChannelState, :start_link, []}
          }
        ]
      else
        []
      end
    end
  end

  defp hackney_pool_children do
    for pool <- enabled_hackney_pools() do
      options = Pleroma.Config.get([:hackney_pools, pool])
      :hackney_pool.child_spec(pool, options)
    end
  end

  defp after_supervisor_start do
    with digest_config <- Application.get_env(:pleroma, :email_notifications)[:digest],
         true <- digest_config[:active] do
      PleromaJobQueue.schedule(
        digest_config[:schedule],
        :digest_emails,
        Pleroma.DigestEmailWorker
      )
    end

    :ok
  end
end
