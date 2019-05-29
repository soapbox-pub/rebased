defmodule Pleroma.Mixfile do
  use Mix.Project

  def project do
    [
      app: :pleroma,
      version: version("0.9.0"),
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      elixirc_options: [warnings_as_errors: true],
      xref: [exclude: [:eldap]],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],

      # Docs
      name: "Pleroma",
      homepage_url: "https://pleroma.social/",
      source_url: "https://git.pleroma.social/pleroma/pleroma",
      docs: [
        source_url_pattern:
          "https://git.pleroma.social/pleroma/pleroma/blob/develop/%{path}#L%{line}",
        logo: "priv/static/static/logo.png",
        extras: ["README.md", "CHANGELOG.md"] ++ Path.wildcard("docs/**/*.md"),
        groups_for_extras: [
          "Installation manuals": Path.wildcard("docs/installation/*.md"),
          Configuration: Path.wildcard("docs/config/*.md"),
          Administration: Path.wildcard("docs/admin/*.md"),
          "Pleroma's APIs and Mastodon API extensions": Path.wildcard("docs/api/*.md")
        ],
        main: "readme",
        output: "priv/static/doc"
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Pleroma.Application, []},
      extra_applications: [:logger, :runtime_tools, :comeonin, :quack],
      included_applications: [:ex_syslogger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    oauth_strategies = String.split(System.get_env("OAUTH_CONSUMER_STRATEGIES") || "")

    oauth_deps =
      for s <- oauth_strategies,
          do: {String.to_atom("ueberauth_#{s}"), ">= 0.0.0"}

    [
      {:phoenix, "~> 1.4.1"},
      {:plug_cowboy, "~> 2.0"},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_sql, "~> 3.1"},
      {:postgrex, ">= 0.13.5"},
      {:gettext, "~> 0.15"},
      {:comeonin, "~> 4.1.1"},
      {:pbkdf2_elixir, "~> 0.12.3"},
      {:trailing_format_plug, "~> 0.0.7"},
      {:html_sanitize_ex, "~> 1.3.0"},
      {:html_entities, "~> 0.4"},
      {:phoenix_html, "~> 2.10"},
      {:calendar, "~> 0.17.4"},
      {:cachex, "~> 3.0.2"},
      {:httpoison, "~> 1.2.0"},
      {:poison, "~> 3.0", override: true},
      {:tesla, "~> 1.2"},
      {:jason, "~> 1.0"},
      {:mogrify, "~> 0.6.1"},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:earmark, "~> 1.3"},
      {:bbcode, "~> 0.1"},
      {:ex_machina, "~> 2.3", only: :test},
      {:credo, "~> 0.9.3", only: [:dev, :test]},
      {:mock, "~> 0.3.3", only: :test},
      {:crypt,
       git: "https://github.com/msantos/crypt", ref: "1f2b58927ab57e72910191a7ebaeff984382a1d3"},
      {:cors_plug, "~> 1.5"},
      {:ex_doc, "~> 0.20.2", only: :dev, runtime: false},
      {:web_push_encryption, "~> 0.2.1"},
      {:swoosh, "~> 0.20"},
      {:phoenix_swoosh, "~> 0.2"},
      {:gen_smtp, "~> 0.13"},
      {:websocket_client, git: "https://github.com/jeremyong/websocket_client.git", only: :test},
      {:floki, "~> 0.20.0"},
      {:ex_syslogger, github: "slashmili/ex_syslogger", tag: "1.4.0"},
      {:timex, "~> 3.5"},
      {:ueberauth, "~> 0.4"},
      {:auto_linker,
       git: "https://git.pleroma.social/pleroma/auto_linker.git",
       ref: "c00c4e75b35367fa42c95ffd9b8c455bf9995829"},
      {:http_signatures,
       git: "https://git.pleroma.social/pleroma/http_signatures.git",
       ref: "9789401987096ead65646b52b5a2ca6bf52fc531"},
      {:pleroma_job_queue, "~> 0.2.0"},
      {:telemetry, "~> 0.3"},
      {:prometheus_ex, "~> 3.0"},
      {:prometheus_plugs, "~> 1.1"},
      {:prometheus_phoenix, "~> 1.2"},
      {:prometheus_ecto, "~> 1.4"},
      {:prometheus_process_collector, "~> 1.4"},
      {:recon, github: "ferd/recon", tag: "2.4.0"},
      {:quack, "~> 0.1.1"},
      {:quantum, "~> 2.3"},
      {:joken, "~> 2.0"},
      {:benchee, "~> 1.0"},
      {:esshd, "~> 0.1.0", runtime: Application.get_env(:esshd, :enabled, false)},
      {:ex_rated, "~> 1.2"},
      {:plug_static_index_html, "~> 1.0.0"},
      {:excoveralls, "~> 0.11.1", only: :test}
    ] ++ oauth_deps
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end

  # Builds a version string made of:
  # * the application version
  # * a pre-release if ahead of the tag: the describe string (-count-commithash)
  # * build info:
  #   * a build name if `PLEROMA_BUILD_NAME` or `:pleroma, :build_name` is defined
  #   * the mix environment if different than prod
  defp version(version) do
    {git_tag, git_pre_release} =
      with {tag, 0} <- System.cmd("git", ["describe", "--tags", "--abbrev=0"]),
           tag = String.trim(tag),
           {describe, 0} <- System.cmd("git", ["describe", "--tags", "--abbrev=8"]),
           describe = String.trim(describe),
           ahead <- String.replace(describe, tag, "") do
        {String.replace_prefix(tag, "v", ""), if(ahead != "", do: String.trim(ahead))}
      else
        _ -> {nil, nil}
      end

    if git_tag && version != git_tag do
      Mix.shell().error(
        "Application version #{inspect(version)} does not match git tag #{inspect(git_tag)}"
      )
    end

    build_name =
      cond do
        name = Application.get_env(:pleroma, :build_name) -> name
        name = System.get_env("PLEROMA_BUILD_NAME") -> name
        true -> nil
      end

    env_name = if Mix.env() != :prod, do: to_string(Mix.env())

    build =
      [build_name, env_name]
      |> Enum.filter(fn string -> string && string != "" end)
      |> Enum.join("-")
      |> (fn
            "" -> nil
            string -> "+" <> string
          end).()

    [version, git_pre_release, build]
    |> Enum.filter(fn string -> string && string != "" end)
    |> Enum.join()
  end
end
