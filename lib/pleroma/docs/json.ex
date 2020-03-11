defmodule Pleroma.Docs.JSON do
  @behaviour Pleroma.Docs.Generator

  @spec process(keyword()) :: {:ok, String.t()}
  def process(descriptions) do
    with path <- "docs/generated_config.json",
         {:ok, file} <- File.open(path, [:write, :utf8]),
         formatted_descriptions <-
           Pleroma.Docs.Generator.convert_to_strings(descriptions),
         json <- Jason.encode!(formatted_descriptions),
         :ok <- IO.write(file, json),
         :ok <- File.close(file) do
      {:ok, path}
    end
  end

  def compile do
    with config <- Pleroma.Config.Loader.read("config/description.exs") do
      config[:pleroma][:config_description]
      |> Pleroma.Docs.Generator.convert_to_strings()
      |> Jason.encode!()
    end
  end
end
