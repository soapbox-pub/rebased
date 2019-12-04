defmodule Pleroma.Docs.JSON do
  @behaviour Pleroma.Docs.Generator

  @spec process(keyword()) :: {:ok, String.t()}
  def process(descriptions) do
    config_path = "docs/generate_config.json"

    with {:ok, file} <- File.open(config_path, [:write, :utf8]),
         json <- generate_json(descriptions),
         :ok <- IO.write(file, json),
         :ok <- File.close(file) do
      {:ok, config_path}
    end
  end

  @spec generate_json([keyword()]) :: String.t()
  def generate_json(descriptions) do
    Jason.encode!(descriptions)
  end
end
