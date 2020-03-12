# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Application do
  use Application

  import Cachex.Spec

  alias Pleroma.Config

  require Logger

  @name Mix.Project.config()[:name]
  @version Mix.Project.config()[:version]
  @repository Mix.Project.config()[:source_url]
  @env Mix.env()

  def name, do: @name
  def version, do: @version
  def named_version, do: @name <> " " <> @version
  def repository, do: @repository

  def user_agent do
    case Config.get([:http, :user_agent], :default) do
      :default ->
        info = "#{Pleroma.Web.base_url()} <#{Config.get([:instance, :email], "")}>"
        named_version() <> "; " <> info

      custom ->
        custom
    end
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    Pleroma.Config.Holder.save_default()
    Pleroma.HTML.compile_scrubbers()
    Config.DeprecationWarnings.warn()
    Pleroma.Plugs.HTTPSecurityPlug.warn_if_disabled()
    Pleroma.Repo.check_migrations_applied!()
    setup_instrumenters()
    load_custom_modules()

    adapter = Application.get_env(:tesla, :adapter)

    if adapter == Tesla.Adapter.Gun do
      if version = Pleroma.OTPVersion.version() do
        [major, minor] =
          version
          |> String.split(".")
          |> Enum.map(&String.to_integer/1)
          |> Enum.take(2)

        if (major == 22 and minor < 2) or major < 22 do
          raise "
            !!!OTP VERSION WARNING!!!
            You are using gun adapter with OTP version #{version}, which doesn't support correct handling of unordered certificates chains.
            "
        end
      else
        raise "
          !!!OTP VERSION WARNING!!!
          To support correct handling of unordered certificates chains - OTP version must be > 22.2.
          "
      end
    end

    # Define workers and child supervisors to be supervised
    children =
      [
        Pleroma.Repo,
        Config.TransferTask,
        Pleroma.Emoji,
        Pleroma.Captcha,
        Pleroma.Plugs.RateLimiter.Supervisor
      ] ++
        cachex_children() ++
        http_children(adapter, @env) ++
        [
          Pleroma.Stats,
          Pleroma.JobQueueMonitor,
          {Oban, Config.get(Oban)}
        ] ++
        task_children(@env) ++
        streamer_child(@env) ++
        chat_child(@env, chat_enabled?()) ++
        [
          Pleroma.Web.Endpoint,
          Pleroma.Gopher.Server
        ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pleroma.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def load_custom_modules do
    dir = Config.get([:modules, :runtime_dir])

    if dir && File.exists?(dir) do
      dir
      |> Pleroma.Utils.compile_dir()
      |> case do
        {:error, _errors, _warnings} ->
          raise "Invalid custom modules"

        {:ok, modules, _warnings} ->
          if @env != :test do
            Enum.each(modules, fn mod ->
              Logger.info("Custom module loaded: #{inspect(mod)}")
            end)
          end

          :ok
      end
    end
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

  defp cachex_children do
    [
      build_cachex("used_captcha", ttl_interval: seconds_valid_interval()),
      build_cachex("user", default_ttl: 25_000, ttl_interval: 1000, limit: 2500),
      build_cachex("object", default_ttl: 25_000, ttl_interval: 1000, limit: 2500),
      build_cachex("rich_media", default_ttl: :timer.minutes(120), limit: 5000),
      build_cachex("scrubber", limit: 2500),
      build_cachex("idempotency", expiration: idempotency_expiration(), limit: 2500),
      build_cachex("web_resp", limit: 2500),
      build_cachex("emoji_packs", expiration: emoji_packs_expiration(), limit: 10),
      build_cachex("failed_proxy_url", limit: 2500)
    ]
  end

  defp emoji_packs_expiration,
    do: expiration(default: :timer.seconds(5 * 60), interval: :timer.seconds(60))

  defp idempotency_expiration,
    do: expiration(default: :timer.seconds(6 * 60 * 60), interval: :timer.seconds(60))

  defp seconds_valid_interval,
    do: :timer.seconds(Config.get!([Pleroma.Captcha, :seconds_valid]))

  defp build_cachex(type, opts),
    do: %{
      id: String.to_atom("cachex_" <> type),
      start: {Cachex, :start_link, [String.to_atom(type <> "_cache"), opts]},
      type: :worker
    }

  defp chat_enabled?, do: Config.get([:chat, :enabled])

  defp streamer_child(:test), do: []

  defp streamer_child(_) do
    [Pleroma.Web.Streamer.supervisor()]
  end

  defp chat_child(_env, true) do
    [Pleroma.Web.ChatChannel.ChatChannelState]
  end

  defp chat_child(_, _), do: []

  defp task_children(:test) do
    [
      %{
        id: :web_push_init,
        start: {Task, :start_link, [&Pleroma.Web.Push.init/0]},
        restart: :temporary
      }
    ]
  end

  defp task_children(_) do
    [
      %{
        id: :web_push_init,
        start: {Task, :start_link, [&Pleroma.Web.Push.init/0]},
        restart: :temporary
      },
      %{
        id: :internal_fetch_init,
        start: {Task, :start_link, [&Pleroma.Web.ActivityPub.InternalFetchActor.init/0]},
        restart: :temporary
      }
    ]
  end

  # start hackney and gun pools in tests
  defp http_children(_, :test) do
    hackney_options = Config.get([:hackney_pools, :federation])
    hackney_pool = :hackney_pool.child_spec(:federation, hackney_options)
    [hackney_pool, Pleroma.Pool.Supervisor]
  end

  defp http_children(Tesla.Adapter.Hackney, _) do
    pools = [:federation, :media]

    pools =
      if Config.get([Pleroma.Upload, :proxy_remote]) do
        [:upload | pools]
      else
        pools
      end

    for pool <- pools do
      options = Config.get([:hackney_pools, pool])
      :hackney_pool.child_spec(pool, options)
    end
  end

  defp http_children(Tesla.Adapter.Gun, _), do: [Pleroma.Pool.Supervisor]

  defp http_children(_, _), do: []
end
