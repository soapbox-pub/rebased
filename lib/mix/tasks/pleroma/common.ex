defmodule Mix.Tasks.Pleroma.Common do
  @shortdoc "Common functions to be reused in mix tasks"
  def start_pleroma do
    Mix.Task.run("app.start")
  end

  def get_option(options, opt, prompt, def \\ nil, defname \\ nil) do
    Keyword.get(options, opt) ||
      case Mix.shell().prompt("#{prompt} [#{defname || def}]") do
        "\n" ->
          case def do
            nil -> get_option(options, opt, prompt, def)
            def -> def
          end

        opt ->
          opt |> String.trim()
      end
  end

  def escape_sh_path(path) do
    ~S(') <> String.replace(path, ~S('), ~S(\')) <> ~S(')
  end
end
