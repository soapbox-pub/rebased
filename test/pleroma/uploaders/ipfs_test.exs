# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Uploaders.IPFSTest do
  use Pleroma.DataCase

  alias Pleroma.Uploaders.IPFS
  alias Tesla.Multipart

  import ExUnit.CaptureLog
  import Mock
  import Mox

  alias Pleroma.UnstubbedConfigMock, as: Config

  describe "get_final_url" do
    setup do
      Config
      |> expect(:get, fn [Pleroma.Uploaders.IPFS] ->
        [post_gateway_url: "http://localhost:5001"]
      end)

      :ok
    end

    test "it returns the final url for put_file" do
      assert IPFS.put_file_endpoint() == "http://localhost:5001/api/v0/add"
    end

    test "it returns the final url for delete_file" do
      assert IPFS.delete_file_endpoint() == "http://localhost:5001/api/v0/files/rm"
    end
  end

  describe "get_file/1" do
    setup do
      Config
      |> expect(:get, fn [Pleroma.Upload, :uploader] -> Pleroma.Uploaders.IPFS end)
      |> expect(:get, fn [Pleroma.Upload, :base_url] -> nil end)
      |> expect(:get, fn [Pleroma.Uploaders.IPFS, :public_endpoint] -> nil end)

      :ok
    end

    test "it returns path to ipfs file with cid as subdomain" do
      Config
      |> expect(:get, fn [Pleroma.Uploaders.IPFS, :get_gateway_url] ->
        "https://{CID}.ipfs.mydomain.com"
      end)

      assert IPFS.get_file("testcid") == {
               :ok,
               {:url, "https://testcid.ipfs.mydomain.com"}
             }
    end

    test "it returns path to ipfs file with cid as path" do
      Config
      |> expect(:get, fn [Pleroma.Uploaders.IPFS, :get_gateway_url] ->
        "https://ipfs.mydomain.com/ipfs/{CID}"
      end)

      assert IPFS.get_file("testcid") == {
               :ok,
               {:url, "https://ipfs.mydomain.com/ipfs/testcid"}
             }
    end
  end

  describe "put_file/1" do
    setup do
      Config
      |> expect(:get, fn [Pleroma.Uploaders.IPFS] ->
        [post_gateway_url: "http://localhost:5001"]
      end)

      file_upload = %Pleroma.Upload{
        name: "image-tet.jpg",
        content_type: "image/jpeg",
        path: "test_folder/image-tet.jpg",
        tempfile: Path.absname("test/instance_static/add/shortcode.png")
      }

      mp =
        Multipart.new()
        |> Multipart.add_content_type_param("charset=utf-8")
        |> Multipart.add_file(file_upload.tempfile)

      [file_upload: file_upload, mp: mp]
    end

    test "save file", %{file_upload: file_upload} do
      with_mock Pleroma.HTTP,
        post: fn "http://localhost:5001/api/v0/add", _mp, [], params: ["cid-version": "1"] ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body:
               "{\"Name\":\"image-tet.jpg\",\"Size\":\"5000\", \"Hash\":\"bafybeicrh7ltzx52yxcwrvxxckfmwhqdgsb6qym6dxqm2a4ymsakeshwoi\"}"
           }}
        end do
        assert IPFS.put_file(file_upload) ==
                 {:ok, {:file, "bafybeicrh7ltzx52yxcwrvxxckfmwhqdgsb6qym6dxqm2a4ymsakeshwoi"}}
      end
    end

    test "returns error", %{file_upload: file_upload} do
      with_mock Pleroma.HTTP,
        post: fn "http://localhost:5001/api/v0/add", _mp, [], params: ["cid-version": "1"] ->
          {:error, "IPFS Gateway upload failed"}
        end do
        assert capture_log(fn ->
                 assert IPFS.put_file(file_upload) == {:error, "IPFS Gateway upload failed"}
               end) =~ "Elixir.Pleroma.Uploaders.IPFS: {:error, \"IPFS Gateway upload failed\"}"
      end
    end

    test "returns error if JSON decode fails", %{file_upload: file_upload} do
      with_mock Pleroma.HTTP, [],
        post: fn "http://localhost:5001/api/v0/add", _mp, [], params: ["cid-version": "1"] ->
          {:ok, %Tesla.Env{status: 200, body: "invalid"}}
        end do
        assert capture_log(fn ->
                 assert IPFS.put_file(file_upload) == {:error, "JSON decode failed"}
               end) =~
                 "Elixir.Pleroma.Uploaders.IPFS: {:error, %Jason.DecodeError"
      end
    end

    test "returns error if JSON body doesn't contain Hash key", %{file_upload: file_upload} do
      with_mock Pleroma.HTTP, [],
        post: fn "http://localhost:5001/api/v0/add", _mp, [], params: ["cid-version": "1"] ->
          {:ok, %Tesla.Env{status: 200, body: "{\"key\": \"value\"}"}}
        end do
        assert IPFS.put_file(file_upload) == {:error, "JSON doesn't contain Hash key"}
      end
    end
  end

  describe "delete_file/1" do
    setup do
      Config
      |> expect(:get, fn [Pleroma.Uploaders.IPFS] ->
        [post_gateway_url: "http://localhost:5001"]
      end)

      :ok
    end

    test_with_mock "deletes file", Pleroma.HTTP,
      post: fn "http://localhost:5001/api/v0/files/rm", "", [], params: [arg: "image.jpg"] ->
        {:ok, %{status: 204}}
      end do
      assert :ok = IPFS.delete_file("image.jpg")
    end
  end
end
