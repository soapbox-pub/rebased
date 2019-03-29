# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Application do
  use Application
  import Supervisor.Spec

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

    # Define workers and child supervisors to be supervised
    children =
      [
        # Start the Ecto repository
        supervisor(Pleroma.Repo, []),
        worker(Pleroma.Emoji, []),
        worker(Pleroma.Captcha, []),
        worker(
          Cachex,
          [
            :used_captcha_cache,
            [
              ttl_interval: :timer.seconds(Pleroma.Config.get!([Pleroma.Captcha, :seconds_valid]))
            ]
          ],
          id: :cachex_used_captcha_cache
        ),
        worker(
          Cachex,
          [
            :user_cache,
            [
              default_ttl: 25_000,
              ttl_interval: 1000,
              limit: 2500
            ]
          ],
          id: :cachex_user
        ),
        worker(
          Cachex,
          [
            :object_cache,
            [
              default_ttl: 25_000,
              ttl_interval: 1000,
              limit: 2500
            ]
          ],
          id: :cachex_object
        ),
        worker(
          Cachex,
          [
            :rich_media_cache,
            [
              default_ttl: :timer.minutes(120),
              limit: 5000
            ]
          ],
          id: :cachex_rich_media
        ),
        worker(
          Cachex,
          [
            :scrubber_cache,
            [
              limit: 2500
            ]
          ],
          id: :cachex_scrubber
        ),
        worker(
          Cachex,
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
          ],
          id: :cachex_idem
        ),
        worker(Pleroma.FlakeId, [])
      ] ++
        hackney_pool_children() ++
        [
          worker(Pleroma.Web.Federator.RetryQueue, []),
          worker(Pleroma.Stats, []),
          worker(Pleroma.Web.Push, []),
          worker(Task, [&Pleroma.Web.Federator.init/0], restart: :temporary)
        ] ++
        streamer_child() ++
        chat_child() ++
        [
          # Start the endpoint when the application starts
          supervisor(Pleroma.Web.Endpoint, []),
          worker(Pleroma.Gopher.Server, [])
        ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pleroma.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def enabled_hackney_pools do
    [:media] ++
      if Application.get_env(:tesla, :adapter) == Tesla.Adapter.Hackney do
        [:federation]
      else
        []
      end ++
      if Pleroma.Config.get([Pleroma.Uploader, :proxy_remote]) do
        [:upload]
      else
        []
      end
  end

  if Mix.env() == :test do
    defp streamer_child, do: []
    defp chat_child, do: []
  else
    defp streamer_child do
      [worker(Pleroma.Web.Streamer, [])]
    end

    defp chat_child do
      if Pleroma.Config.get([:chat, :enabled]) do
        [worker(Pleroma.Web.ChatChannel.ChatChannelState, [])]
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
end
