defmodule Pleroma.Web.MediaProxy.Invalidation.HttpTest do
  use ExUnit.Case
  alias Pleroma.Web.MediaProxy.Invalidation

  import ExUnit.CaptureLog
  import Tesla.Mock

  test "logs hasn't error message when request is valid" do
    mock(fn
      %{method: :purge, url: "http://example.com/media/example.jpg"} ->
        %Tesla.Env{status: 200}
    end)

    refute capture_log(fn ->
             assert Invalidation.Http.purge(
                      ["http://example.com/media/example.jpg"],
                      %{}
                    ) == {:ok, "success"}
           end) =~ "Error while cache purge"
  end

  test "it write error message in logs when request invalid" do
    mock(fn
      %{method: :purge, url: "http://example.com/media/example1.jpg"} ->
        %Tesla.Env{status: 404}
    end)

    assert capture_log(fn ->
             assert Invalidation.Http.purge(
                      ["http://example.com/media/example1.jpg"],
                      %{}
                    ) == {:ok, "success"}
           end) =~ "Error while cache purge: url - http://example.com/media/example1.jpg"
  end
end
