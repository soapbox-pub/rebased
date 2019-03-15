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
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),

      # Docs
      name: "Pleroma",
      source_url: "https://git.pleroma.social/pleroma/pleroma",
      source_url_pattern:
        "https://git.pleroma.social/pleroma/pleroma/blob/develop/%{path}#L%{line}",
      homepage_url: "https://pleroma.social/",
      docs: [
        logo: "priv/static/static/logo.png",
        extras: [
          "README.md",
          "docs/Admin-API.md",
          "docs/Clients.md",
          "docs/config.md",
          "docs/Custom-Emoji.md",
          "docs/Differences-in-MastodonAPI-Responses.md",
          "docs/Message-Rewrite-Facility-configuration.md",
          "docs/Pleroma-API.md",
          "docs/static_dir.md"
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
      extra_applications: [:logger, :runtime_tools, :comeonin],
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
    [
      {:phoenix, "~> 1.4.1"},
      {:plug_cowboy, "~> 2.0"},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_ecto, "~> 3.3"},
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
      {:tesla, "~> 1.2"},
      {:jason, "~> 1.0"},
      {:mogrify, "~> 0.6.1"},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:earmark, "~> 1.3"},
      {:ex_machina, "~> 2.3", only: :test},
      {:credo, "~> 0.9.3", only: [:dev, :test]},
      {:mock, "~> 0.3.1", only: :test},
      {:crypt,
       git: "https://github.com/msantos/crypt", ref: "1f2b58927ab57e72910191a7ebaeff984382a1d3"},
      {:cors_plug, "~> 1.5"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:web_push_encryption, "~> 0.2.1"},
      {:swoosh, "~> 0.20"},
      {:gen_smtp, "~> 0.13"},
      {:websocket_client, git: "https://github.com/jeremyong/websocket_client.git", only: :test},
      {:floki, "~> 0.20.0"},
      {:ex_syslogger, github: "slashmili/ex_syslogger", tag: "1.4.0"},
      {:timex, "~> 3.5"},
      {:auto_linker,
       git: "https://git.pleroma.social/pleroma/auto_linker.git",
       ref: "94193ca5f97c1f9fdf3d1469653e2d46fac34bcd"}
    ]
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
