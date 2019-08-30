defmodule Pleroma.Docs.Markdown do
  @behaviour Pleroma.Docs.Generator

  @spec process(keyword()) :: {:ok, String.t()}
  def process(descriptions) do
    config_path = "docs/config.md"
    {:ok, file} = File.open(config_path, [:write])
    IO.write(file, "# Configuration\r\n\r\n")
    IO.write(file, "Date of generation: #{Date.utc_today()}\r\n\r\n")

    IO.write(
      file,
      "This file describe the configuration, it is recommended to edit the relevant `*.secret.exs` file instead of the others founds in the ``config`` directory.  \r\n
      If you run Pleroma with ``MIX_ENV=prod`` the file is ``prod.secret.exs``, otherwise it is ``dev.secret.exs``.\r\n\r\n"
    )

    for group <- descriptions do
      if is_nil(group[:key]) do
        IO.write(file, "## #{inspect(group[:group])}\r\n\r\n")
      else
        IO.write(file, "## #{inspect(group[:key])}\r\n\r\n")
      end

      IO.write(file, "#{group[:description]}  \r\n\r\n")

      for child <- group[:children] do
        print_child_header(file, child)

        print_suggestions(file, child[:suggestions])

        if child[:children] do
          for subchild <- child[:children] do
            print_child_header(file, subchild)

            print_suggestions(file, subchild[:suggestions])
          end
        end
      end

      IO.write(file, "\r\n")
    end

    :ok = File.close(file)
    {:ok, config_path}
  end

  defp print_suggestion(file, suggestion) when is_list(suggestion) do
    IO.write(file, "    `#{inspect(suggestion)}`\r\n")
  end

  defp print_suggestion(file, suggestion) when is_function(suggestion) do
    IO.write(file, "    `#{inspect(suggestion.())}`\r\n")
  end

  defp print_suggestion(file, suggestion, as_list \\ false) do
    list_mark = if as_list, do: "*", else: ""
    IO.write(file, "    #{list_mark} `#{inspect(suggestion)}`\r\n")
  end

  defp print_suggestions(_file, nil), do: nil

  defp print_suggestions(file, suggestions) do
    IO.write(file, "    Suggestions:  \r\n")

    if length(suggestions) > 1 do
      for suggestion <- suggestions do
        print_suggestion(file, suggestion, true)
      end
    else
      print_suggestion(file, List.first(suggestions))
    end
  end

  defp print_child_header(file, child) do
    IO.write(file, "* `#{inspect(child[:key])}`  \r\n")
    IO.write(file, "    #{child[:description]}  \r\n")
    IO.write(file, "    Type: `#{inspect(child[:type])}`  \r\n")
  end
end
