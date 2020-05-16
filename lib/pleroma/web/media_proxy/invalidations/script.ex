defmodule Pleroma.Web.MediaProxy.Invalidation.Script do
  @behaviour Pleroma.Web.MediaProxy.Invalidation

  @impl Pleroma.Web.MediaProxy.Invalidation
  def purge(urls, %{script_path: script_path} = _options) do
    args =
      urls
      |> List.wrap()
      |> Enum.uniq()
      |> Enum.join(" ")

    System.cmd(Path.expand(script_path), [args])
    {:ok, "success"}
  end
end
