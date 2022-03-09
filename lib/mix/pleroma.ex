# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Pleroma do
  @apps [
    :restarter,
    :ecto,
    :ecto_sql,
    :postgrex,
    :db_connection,
    :cachex,
    :flake_id,
    :swoosh,
    :timex,
    :fast_html,
    :oban
  ]
  @cachex_children ["object", "user", "scrubber", "web_resp"]
  @doc "Common functions to be reused in mix tasks"
  def start_pleroma do
    Pleroma.Config.Holder.save_default()
    Pleroma.Config.Oban.warn()
    Pleroma.Application.limiters_setup()
    Application.put_env(:phoenix, :serve_endpoints, false, persistent: true)

    unless System.get_env("DEBUG") do
      Logger.remove_backend(:console)
    end

    adapter = Application.get_env(:tesla, :adapter)

    apps =
      if adapter == Tesla.Adapter.Gun do
        [:gun | @apps]
      else
        [:hackney | @apps]
      end

    Enum.each(apps, &Application.ensure_all_started/1)

    oban_config = [
      crontab: [],
      repo: Pleroma.Repo,
      log: false,
      queues: [],
      plugins: []
    ]

    children =
      [
        Pleroma.Repo,
        Pleroma.Emoji,
        {Pleroma.Config.TransferTask, false},
        Pleroma.Web.Endpoint,
        {Oban, oban_config},
        {Majic.Pool,
         [name: Pleroma.MajicPool, pool_size: Pleroma.Config.get([:majic_pool, :size], 2)]}
      ] ++
        http_children(adapter)

    cachex_children = Enum.map(@cachex_children, &Pleroma.Application.build_cachex(&1, []))

    Supervisor.start_link(children ++ cachex_children,
      strategy: :one_for_one,
      name: Pleroma.Supervisor
    )

    if Pleroma.Config.get(:env) not in [:test, :benchmark] do
      pleroma_rebooted?()
    end
  end

  defp pleroma_rebooted? do
    if Restarter.Pleroma.rebooted?() do
      :ok
    else
      Process.sleep(10)
      pleroma_rebooted?()
    end
  end

  def load_pleroma do
    Application.load(:pleroma)
  end

  def get_option(options, opt, prompt, defval \\ nil, defname \\ nil) do
    Keyword.get(options, opt) || shell_prompt(prompt, defval, defname)
  end

  def shell_prompt(prompt, defval \\ nil, defname \\ nil) do
    prompt_message = "#{prompt} [#{defname || defval}] "

    input =
      if mix_shell?(),
        do: Mix.shell().prompt(prompt_message),
        else: :io.get_line(prompt_message)

    case input do
      "\n" ->
        case defval do
          nil ->
            shell_prompt(prompt, defval, defname)

          defval ->
            defval
        end

      input ->
        String.trim(input)
    end
  end

  def shell_info(message) do
    if mix_shell?(),
      do: Mix.shell().info(message),
      else: IO.puts(message)
  end

  def shell_error(message) do
    if mix_shell?(),
      do: Mix.shell().error(message),
      else: IO.puts(:stderr, message)
  end

  @doc "Performs a safe check whether `Mix.shell/0` is available (does not raise if Mix is not loaded)"
  def mix_shell?, do: :erlang.function_exported(Mix, :shell, 0)

  def escape_sh_path(path) do
    ~S(') <> String.replace(path, ~S('), ~S(\')) <> ~S(')
  end

  defp http_children(Tesla.Adapter.Gun) do
    Pleroma.Gun.ConnectionPool.children() ++
      [{Task, &Pleroma.HTTP.AdapterHelper.Gun.limiter_setup/0}]
  end

  defp http_children(_), do: []
end
