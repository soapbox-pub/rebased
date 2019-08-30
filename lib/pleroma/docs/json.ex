defmodule Pleroma.Docs.JSON do
  @behaviour Pleroma.Docs.Formatter
  def process(descriptions) do
    config_path = "docs/generate_config.json"
    {:ok, file} = File.open(config_path, [:write])
    json = generate_json(descriptions)
    IO.write(file, json)
    :ok = File.close(file)
    {:ok, config_path}
  end

  def generate_json(descriptions) do
    Jason.encode!(descriptions)
  end
end
