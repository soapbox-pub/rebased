defmodule Pleroma.Mixfile do
  use Mix.Project

  def project do
    [
      app: :pleroma,
      version: version("1.1.50"),
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      elixirc_options: [warnings_as_errors: true],
      xref: [exclude: [:eldap]],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: ["coveralls.html": :test],
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
      ],
      releases: [
        pleroma: [
          include_executables_for: [:unix],
          applications: [ex_syslogger: :load, syslog: :load],
          steps: [:assemble, &copy_files/1, &copy_nginx_config/1]
        ]
      ]
    ]
  end

  def copy_files(%{path: target_path} = release) do
    File.cp_r!("./rel/files", target_path)
    release
  end

  def copy_nginx_config(%{path: target_path} = release) do
    File.cp!(
      "./installation/pleroma.nginx",
      Path.join([target_path, "installation", "pleroma.nginx"])
    )

    release
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Pleroma.Application, []},
      extra_applications: [:logger, :runtime_tools, :comeonin, :quack, :myhtmlex, :swarm],
      included_applications: [:ex_syslogger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:benchmark), do: ["lib", "benchmarks"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies OAuth dependencies.
  defp oauth_deps do
    oauth_strategy_packages =
      System.get_env("OAUTH_CONSUMER_STRATEGIES")
      |> to_string()
      |> String.split()
      |> Enum.map(fn strategy_entry ->
        with [_strategy, dependency] <- String.split(strategy_entry, ":") do
          dependency
        else
          [strategy] -> "ueberauth_#{strategy}"
        end
      end)

    for s <- oauth_strategy_packages, do: {String.to_atom(s), ">= 0.0.0"}
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.4.8"},
      {:tzdata, "~> 0.5.21"},
      {:plug_cowboy, "~> 2.0"},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_sql, "~> 3.2"},
      {:postgrex, ">= 0.13.5"},
      {:oban, "~> 0.8.1"},
      {:quantum, "~> 2.3"},
      {:gettext, "~> 0.15"},
      {:comeonin, "~> 4.1.1"},
      {:pbkdf2_elixir, "~> 0.12.3"},
      {:trailing_format_plug, "~> 0.0.7"},
      {:fast_sanitize,
       git: "https://git.pleroma.social/pleroma/fast_sanitize.git",
       ref: "1af67547a02a104e26c99d03012383e8643bc4c2"},
      {:html_entities, "~> 0.4"},
      {:phoenix_html, "~> 2.10"},
      {:calendar, "~> 0.17.4"},
      {:cachex, "~> 3.0.2"},
      {:poison, "~> 3.0", override: true},
      {:tesla, "~> 1.3", override: true},
      {:jason, "~> 1.0"},
      {:mogrify, "~> 0.6.1"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:sweet_xml, "~> 0.6.6"},
      {:earmark, "~> 1.3"},
      {:bbcode, "~> 0.1.1"},
      {:ex_machina, "~> 2.3", only: :test},
      {:credo, "~> 0.9.3", only: [:dev, :test]},
      {:mock, "~> 0.3.3", only: :test},
      {:crypt,
       git: "https://github.com/msantos/crypt", ref: "1f2b58927ab57e72910191a7ebaeff984382a1d3"},
      {:cors_plug, "~> 1.5"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:web_push_encryption, "~> 0.2.1"},
      {:swoosh, "~> 0.23.2"},
      {:phoenix_swoosh, "~> 0.2"},
      {:gen_smtp, "~> 0.13"},
      {:websocket_client, git: "https://github.com/jeremyong/websocket_client.git", only: :test},
      {:floki, "~> 0.23.0"},
      {:ex_syslogger, github: "slashmili/ex_syslogger", tag: "1.4.0"},
      {:timex, "~> 3.5"},
      {:ueberauth, "~> 0.4"},
      {:auto_linker,
       git: "https://git.pleroma.social/pleroma/auto_linker.git",
       ref: "95e8188490e97505c56636c1379ffdf036c1fdde"},
      {:http_signatures,
       git: "https://git.pleroma.social/pleroma/http_signatures.git",
       ref: "293d77bb6f4a67ac8bde1428735c3b42f22cbb30"},
      {:telemetry, "~> 0.3"},
      {:poolboy, "~> 1.5"},
      {:prometheus_ex, "~> 3.0"},
      {:prometheus_plugs, "~> 1.1"},
      {:prometheus_phoenix, "~> 1.3"},
      {:prometheus_ecto, "~> 1.4"},
      {:recon, github: "ferd/recon", tag: "2.4.0"},
      {:quack, "~> 0.1.1"},
      {:joken, "~> 2.0"},
      {:benchee, "~> 1.0"},
      {:esshd, "~> 0.1.0", runtime: Application.get_env(:esshd, :enabled, false)},
      {:ex_rated, "~> 1.3"},
      {:ex_const, "~> 0.2"},
      {:plug_static_index_html, "~> 1.0.0"},
      {:excoveralls, "~> 0.11.1", only: :test},
      {:flake_id, "~> 0.1.0"},
      {:remote_ip,
       git: "https://git.pleroma.social/pleroma/remote_ip.git",
       ref: "825dc00aaba5a1b7c4202a532b696b595dd3bcb3"},
      {:mox, "~> 0.5", only: :test}
    ] ++ oauth_deps()
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.migrate": ["pleroma.ecto.migrate"],
      "ecto.rollback": ["pleroma.ecto.rollback"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
      docs: ["pleroma.docs", "docs"]
    ]
  end

  # Builds a version string made of:
  # * the application version
  # * a pre-release if ahead of the tag: the describe string (-count-commithash)
  # * branch name
  # * build metadata:
  #   * a build name if `PLEROMA_BUILD_NAME` or `:pleroma, :build_name` is defined
  #   * the mix environment if different than prod
  defp version(version) do
    identifier_filter = ~r/[^0-9a-z\-]+/i

    # Pre-release version, denoted from patch version with a hyphen
    {git_tag, git_pre_release} =
      with {tag, 0} <-
             System.cmd("git", ["describe", "--tags", "--abbrev=0"], stderr_to_stdout: true),
           tag = String.trim(tag),
           {describe, 0} <- System.cmd("git", ["describe", "--tags", "--abbrev=8"]),
           describe = String.trim(describe),
           ahead <- String.replace(describe, tag, ""),
           ahead <- String.trim_leading(ahead, "-") do
        {String.replace_prefix(tag, "v", ""), if(ahead != "", do: String.trim(ahead))}
      else
        _ ->
          {commit_hash, 0} = System.cmd("git", ["rev-parse", "--short", "HEAD"])
          {nil, "0-g" <> String.trim(commit_hash)}
      end

    if git_tag && version != git_tag do
      Mix.shell().error(
        "Application version #{inspect(version)} does not match git tag #{inspect(git_tag)}"
      )
    end

    # Branch name as pre-release version component, denoted with a dot
    branch_name =
      with {branch_name, 0} <- System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"]),
           branch_name <- String.trim(branch_name),
           branch_name <- System.get_env("PLEROMA_BUILD_BRANCH") || branch_name,
           true <-
             !Enum.any?(["master", "HEAD", "release/", "stable"], fn name ->
               String.starts_with?(name, branch_name)
             end) do
        branch_name =
          branch_name
          |> String.trim()
          |> String.replace(identifier_filter, "-")

        branch_name
      end

    build_name =
      cond do
        name = Application.get_env(:pleroma, :build_name) -> name
        name = System.get_env("PLEROMA_BUILD_NAME") -> name
        true -> nil
      end

    env_name = if Mix.env() != :prod, do: to_string(Mix.env())
    env_override = System.get_env("PLEROMA_BUILD_ENV")

    env_name =
      case env_override do
        nil -> env_name
        env_override when env_override in ["", "prod"] -> nil
        env_override -> env_override
      end

    # Pre-release version, denoted by appending a hyphen
    # and a series of dot separated identifiers
    pre_release =
      [git_pre_release, branch_name]
      |> Enum.filter(fn string -> string && string != "" end)
      |> Enum.join(".")
      |> (fn
            "" -> nil
            string -> "-" <> String.replace(string, identifier_filter, "-")
          end).()

    # Build metadata, denoted with a plus sign
    build_metadata =
      [build_name, env_name]
      |> Enum.filter(fn string -> string && string != "" end)
      |> Enum.join(".")
      |> (fn
            "" -> nil
            string -> "+" <> String.replace(string, identifier_filter, "-")
          end).()

    [version, pre_release, build_metadata]
    |> Enum.filter(fn string -> string && string != "" end)
    |> Enum.join()
  end
end
