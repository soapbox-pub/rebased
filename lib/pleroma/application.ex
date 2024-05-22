# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Application do
  use Application

  import Cachex.Spec

  alias Pleroma.Config

  require Logger

  @name Mix.Project.config()[:name]
  @compat_name Mix.Project.config()[:compat_name]
  @version Mix.Project.config()[:version]
  @repository Mix.Project.config()[:source_url]

  def name, do: @name
  def compat_name, do: @compat_name
  def version, do: @version
  def named_version, do: @name <> " " <> @version
  def compat_version, do: @compat_name <> " " <> @version
  def repository, do: @repository

  def user_agent do
    if Process.whereis(Pleroma.Web.Endpoint) do
      case Config.get([:http, :user_agent], :default) do
        :default ->
          info = "#{Pleroma.Web.Endpoint.url()} <#{Config.get([:instance, :email], "")}>"
          compat_version() <> "; " <> info

        custom ->
          custom
      end
    else
      # fallback, if endpoint is not started yet
      "Pleroma Data Loader"
    end
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    # Scrubbers are compiled at runtime and therefore will cause a conflict
    # every time the application is restarted, so we disable module
    # conflicts at runtime
    Code.compiler_options(ignore_module_conflict: true)
    # Disable warnings_as_errors at runtime, it breaks Phoenix live reload
    # due to protocol consolidation warnings
    Code.compiler_options(warnings_as_errors: false)
    Pleroma.Telemetry.Logger.attach()
    Config.Holder.save_default()
    Pleroma.HTML.compile_scrubbers()
    Pleroma.Config.Oban.warn()
    Config.DeprecationWarnings.warn()
    Pleroma.Web.Plugs.HTTPSecurityPlug.warn_if_disabled()
    Pleroma.ApplicationRequirements.verify!()
    load_custom_modules()
    Pleroma.Docs.JSON.compile()
    limiters_setup()

    adapter = Application.get_env(:tesla, :adapter)

    if match?({Tesla.Adapter.Finch, _}, adapter) do
      Logger.info("Starting Finch")
      Finch.start_link(name: MyFinch)
    end

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
            You are using gun adapter with OTP version #{version}, which doesn't support correct handling of unordered certificates chains. Please update your Erlang/OTP to at least 22.2.
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
        Pleroma.PromEx,
        Pleroma.Repo,
        Config.TransferTask,
        Pleroma.Emoji,
        Pleroma.Web.Plugs.RateLimiter.Supervisor,
        {Task.Supervisor, name: Pleroma.TaskSupervisor}
      ] ++
        cachex_children() ++
        http_children(adapter) ++
        [
          Pleroma.Stats,
          Pleroma.JobQueueMonitor,
          {Majic.Pool, [name: Pleroma.MajicPool, pool_size: Config.get([:majic_pool, :size], 2)]},
          {Oban, Config.get(Oban)},
          Pleroma.Web.Endpoint,
          TzWorld.Backend.DetsWithIndexCache
        ] ++
        task_children() ++
        streamer_registry() ++
        background_migrators() ++
        [Pleroma.Gopher.Server]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    # If we have a lot of caches, default max_restarts can cause test
    # resets to fail.
    # Go for the default 3 unless we're in test
    max_restarts = Application.get_env(:pleroma, __MODULE__)[:max_restarts]

    opts = [strategy: :one_for_one, name: Pleroma.Supervisor, max_restarts: max_restarts]
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
          if Application.get_env(:pleroma, __MODULE__)[:load_custom_modules] do
            Enum.each(modules, fn mod ->
              Logger.info("Custom module loaded: #{inspect(mod)}")
            end)
          end

          :ok
      end
    end
  end

  defp cachex_children do
    [
      build_cachex("used_captcha", ttl_interval: seconds_valid_interval()),
      build_cachex("user", default_ttl: 25_000, ttl_interval: 1000, limit: 2500),
      build_cachex("object", default_ttl: 25_000, ttl_interval: 1000, limit: 2500),
      build_cachex("rich_media", default_ttl: :timer.minutes(120), limit: 5000),
      build_cachex("scrubber", limit: 2500),
      build_cachex("scrubber_management", limit: 2500),
      build_cachex("idempotency", expiration: idempotency_expiration(), limit: 2500),
      build_cachex("web_resp", limit: 2500),
      build_cachex("emoji_packs", expiration: emoji_packs_expiration(), limit: 10),
      build_cachex("failed_proxy_url", limit: 2500),
      build_cachex("failed_media_helper_url", default_ttl: :timer.minutes(15), limit: 2_500),
      build_cachex("banned_urls", default_ttl: :timer.hours(24 * 30), limit: 5_000),
      build_cachex("chat_message_id_idempotency_key",
        expiration: chat_message_id_idempotency_key_expiration(),
        limit: 500_000
      ),
      build_cachex("rel_me", default_ttl: :timer.minutes(30), limit: 2_500),
      build_cachex("host_meta", default_ttl: :timer.minutes(120), limit: 5000),
      build_cachex("anti_duplication_mrf", limit: 5_000),
      build_cachex("translations", default_ttl: :timer.hours(24), limit: 5_000),
      build_cachex("domain", limit: 2500)
    ]
  end

  defp emoji_packs_expiration,
    do: expiration(default: :timer.seconds(5 * 60), interval: :timer.seconds(60))

  defp idempotency_expiration,
    do: expiration(default: :timer.seconds(6 * 60 * 60), interval: :timer.seconds(60))

  defp chat_message_id_idempotency_key_expiration,
    do: expiration(default: :timer.minutes(2), interval: :timer.seconds(60))

  defp seconds_valid_interval,
    do: :timer.seconds(Config.get!([Pleroma.Captcha, :seconds_valid]))

  @spec build_cachex(String.t(), keyword()) :: map()
  def build_cachex(type, opts),
    do: %{
      id: String.to_atom("cachex_" <> type),
      start: {Cachex, :start_link, [String.to_atom(type <> "_cache"), opts]},
      type: :worker
    }

  defp streamer_registry do
    if Application.get_env(:pleroma, __MODULE__)[:streamer_registry] do
      [
        {Registry,
         [
           name: Pleroma.Web.Streamer.registry(),
           keys: :duplicate,
           partitions: System.schedulers_online()
         ]}
      ]
    else
      []
    end
  end

  defp background_migrators do
    if Application.get_env(:pleroma, __MODULE__)[:background_migrators] do
      [
        Pleroma.Migrators.HashtagsTableMigrator,
        Pleroma.Migrators.ContextObjectsDeletionMigrator
      ]
    else
      []
    end
  end

  defp task_children do
    children = [
      %{
        id: :web_push_init,
        start: {Task, :start_link, [&Pleroma.Web.Push.init/0]},
        restart: :temporary
      }
    ]

    if Application.get_env(:pleroma, __MODULE__)[:internal_fetch] do
      children ++
        [
          %{
            id: :internal_fetch_init,
            start: {Task, :start_link, [&Pleroma.Web.ActivityPub.InternalFetchActor.init/0]},
            restart: :temporary
          }
        ]
    else
      children
    end
  end

  # start hackney and gun pools in tests
  defp http_children(adapter) do
    if Application.get_env(:pleroma, __MODULE__)[:test_http_pools] do
      http_children_hackney() ++ http_children_gun()
    else
      cond do
        match?(Tesla.Adapter.Hackney, adapter) -> http_children_hackney()
        match?(Tesla.Adapter.Gun, adapter) -> http_children_gun()
        true -> []
      end
    end
  end

  defp http_children_hackney do
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

  defp http_children_gun do
    Pleroma.Gun.ConnectionPool.children() ++
      [{Task, &Pleroma.HTTP.AdapterHelper.Gun.limiter_setup/0}]
  end

  @spec limiters_setup() :: :ok
  def limiters_setup do
    config = Config.get(ConcurrentLimiter, [])

    [
      Pleroma.Web.RichMedia.Helpers,
      Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy,
      Pleroma.Search,
      Pleroma.Webhook.Notify
    ]
    |> Enum.each(fn module ->
      mod_config = Keyword.get(config, module, [])

      max_running = Keyword.get(mod_config, :max_running, 5)
      max_waiting = Keyword.get(mod_config, :max_waiting, 5)

      ConcurrentLimiter.new(module, max_running, max_waiting)
    end)
  end
end
