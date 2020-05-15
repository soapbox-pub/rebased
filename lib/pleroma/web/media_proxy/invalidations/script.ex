defmodule Pleroma.Web.MediaProxy.Invalidation.Script do
  @behaviour Pleroma.Web.MediaProxy.Invalidation

  @impl Pleroma.Web.MediaProxy.Invalidation
  def purge(urls, %{script_path: script_path} = options) do
    script_args = List.wrap(Map.get(options, :script_args, []))
    System.cmd(Path.expand(script_path), [urls] ++ script_args)
    {:ok, "success"}
  end
end
