defmodule Mix.Tasks.Pleroma.TestRunner do
  @shortdoc "Retries tests once if they fail"

  use Mix.Task

  def run(args \\ []) do
    case System.cmd("mix", ["test"] ++ args, into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        :ok

      _ ->
        retry(args)
    end
  end

  def retry(args) do
    case System.cmd("mix", ["test", "--failed"] ++ args, into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        :ok

      _ ->
        exit(1)
    end
  end
end
