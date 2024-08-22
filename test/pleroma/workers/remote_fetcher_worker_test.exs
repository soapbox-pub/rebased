# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.RemoteFetcherWorkerTest do
  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Workers.RemoteFetcherWorker

  @deleted_object_one "https://deleted-404.example.com/"
  @deleted_object_two "https://deleted-410.example.com/"
  @unauthorized_object "https://unauthorized.example.com/"
  @depth_object "https://depth.example.com/"
  @content_type_object "https://bad_content_type.example.com/"

  describe "RemoteFetcherWorker" do
    setup do
      Tesla.Mock.mock(fn
        %{method: :get, url: @deleted_object_one} ->
          %Tesla.Env{
            status: 404
          }

        %{method: :get, url: @deleted_object_two} ->
          %Tesla.Env{
            status: 410
          }

        %{method: :get, url: @unauthorized_object} ->
          %Tesla.Env{
            status: 403
          }

        %{method: :get, url: @depth_object} ->
          %Tesla.Env{
            status: 200
          }

        %{method: :get, url: @content_type_object} ->
          %Tesla.Env{
            status: 200,
            headers: [{"content-type", "application/json"}],
            body: File.read!("test/fixtures/spoofed-object.json")
          }
      end)
    end

    test "does not retry jobs for a deleted object" do
      [
        %{"op" => "fetch_remote", "id" => @deleted_object_one},
        %{"op" => "fetch_remote", "id" => @deleted_object_two}
      ]
      |> Enum.each(fn job -> assert {:cancel, _} = perform_job(RemoteFetcherWorker, job) end)
    end

    test "does not retry jobs for an unauthorized object" do
      assert {:cancel, _} =
               perform_job(RemoteFetcherWorker, %{
                 "op" => "fetch_remote",
                 "id" => @unauthorized_object
               })
    end

    test "does not retry jobs for an an object that exceeded depth" do
      clear_config([:instance, :federation_incoming_replies_max_depth], 0)

      assert {:cancel, _} =
               perform_job(RemoteFetcherWorker, %{
                 "op" => "fetch_remote",
                 "id" => @depth_object,
                 "depth" => 1
               })
    end

    test "does not retry jobs for when object returns wrong content type" do
      assert {:cancel, _} =
               perform_job(RemoteFetcherWorker, %{
                 "op" => "fetch_remote",
                 "id" => @content_type_object
               })
    end
  end
end
