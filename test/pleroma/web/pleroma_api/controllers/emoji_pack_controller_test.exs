# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EmojiPackControllerTest do
  use Pleroma.Web.ConnCase, async: false

  import Mock
  import Tesla.Mock
  import Pleroma.Factory

  @emoji_path Path.join(
                Pleroma.Config.get!([:instance, :static_dir]),
                "emoji"
              )

  setup do: clear_config([:instance, :public], true)

  setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    admin_conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    Pleroma.Emoji.reload()
    {:ok, %{admin_conn: admin_conn}}
  end

  test "GET /api/pleroma/emoji/packs when :public: false", %{conn: conn} do
    clear_config([:instance, :public], false)
    conn |> get("/api/pleroma/emoji/packs") |> json_response_and_validate_schema(200)
  end

  test "GET /api/pleroma/emoji/packs", %{conn: conn} do
    resp = conn |> get("/api/pleroma/emoji/packs") |> json_response_and_validate_schema(200)

    assert resp["count"] == 4

    assert resp["packs"]
           |> Map.keys()
           |> length() == 4

    shared = resp["packs"]["test_pack"]
    assert shared["files"] == %{"blank" => "blank.png", "blank2" => "blank2.png"}
    assert Map.has_key?(shared["pack"], "download-sha256")
    assert shared["pack"]["can-download"]
    assert shared["pack"]["share-files"]

    non_shared = resp["packs"]["test_pack_nonshared"]
    assert non_shared["pack"]["share-files"] == false
    assert non_shared["pack"]["can-download"] == false

    resp =
      conn
      |> get("/api/pleroma/emoji/packs?page_size=1")
      |> json_response_and_validate_schema(200)

    assert resp["count"] == 4

    packs = Map.keys(resp["packs"])

    assert length(packs) == 1

    [pack1] = packs

    resp =
      conn
      |> get("/api/pleroma/emoji/packs?page_size=1&page=2")
      |> json_response_and_validate_schema(200)

    assert resp["count"] == 4
    packs = Map.keys(resp["packs"])
    assert length(packs) == 1
    [pack2] = packs

    resp =
      conn
      |> get("/api/pleroma/emoji/packs?page_size=1&page=3")
      |> json_response_and_validate_schema(200)

    assert resp["count"] == 4
    packs = Map.keys(resp["packs"])
    assert length(packs) == 1
    [pack3] = packs

    resp =
      conn
      |> get("/api/pleroma/emoji/packs?page_size=1&page=4")
      |> json_response_and_validate_schema(200)

    assert resp["count"] == 4
    packs = Map.keys(resp["packs"])
    assert length(packs) == 1
    [pack4] = packs
    assert [pack1, pack2, pack3, pack4] |> Enum.uniq() |> length() == 4
  end

  describe "GET /api/pleroma/emoji/packs/remote" do
    test "shareable instance", %{admin_conn: admin_conn, conn: conn} do
      resp =
        conn
        |> get("/api/pleroma/emoji/packs?page=2&page_size=1")
        |> json_response_and_validate_schema(200)

      mock(fn
        %{method: :get, url: "https://example.com/.well-known/nodeinfo"} ->
          json(%{links: [%{href: "https://example.com/nodeinfo/2.1.json"}]})

        %{method: :get, url: "https://example.com/nodeinfo/2.1.json"} ->
          json(%{metadata: %{features: ["shareable_emoji_packs"]}})

        %{method: :get, url: "https://example.com/api/pleroma/emoji/packs?page=2&page_size=1"} ->
          json(resp)
      end)

      assert admin_conn
             |> get("/api/pleroma/emoji/packs/remote?url=https://example.com&page=2&page_size=1")
             |> json_response_and_validate_schema(200) == resp
    end

    test "non shareable instance", %{admin_conn: admin_conn} do
      mock(fn
        %{method: :get, url: "https://example.com/.well-known/nodeinfo"} ->
          json(%{links: [%{href: "https://example.com/nodeinfo/2.1.json"}]})

        %{method: :get, url: "https://example.com/nodeinfo/2.1.json"} ->
          json(%{metadata: %{features: []}})
      end)

      assert admin_conn
             |> get("/api/pleroma/emoji/packs/remote?url=https://example.com")
             |> json_response_and_validate_schema(500) == %{
               "error" => "The requested instance does not support sharing emoji packs"
             }
    end
  end

  describe "GET /api/pleroma/emoji/packs/archive?name=:name" do
    test "download shared pack", %{conn: conn} do
      resp =
        conn
        |> get("/api/pleroma/emoji/packs/archive?name=test_pack")
        |> response(200)

      {:ok, arch} = :zip.unzip(resp, [:memory])

      assert Enum.find(arch, fn {n, _} -> n == 'pack.json' end)
      assert Enum.find(arch, fn {n, _} -> n == 'blank.png' end)
    end

    test "non existing pack", %{conn: conn} do
      assert conn
             |> get("/api/pleroma/emoji/packs/archive?name=test_pack_for_import")
             |> json_response_and_validate_schema(:not_found) == %{
               "error" => "Pack test_pack_for_import does not exist"
             }
    end

    test "non downloadable pack", %{conn: conn} do
      assert conn
             |> get("/api/pleroma/emoji/packs/archive?name=test_pack_nonshared")
             |> json_response_and_validate_schema(:forbidden) == %{
               "error" =>
                 "Pack test_pack_nonshared cannot be downloaded from this instance, either pack sharing was disabled for this pack or some files are missing"
             }
    end
  end

  describe "POST /api/pleroma/emoji/packs/download" do
    test "shared pack from remote and non shared from fallback-src", %{
      admin_conn: admin_conn,
      conn: conn
    } do
      mock(fn
        %{method: :get, url: "https://example.com/.well-known/nodeinfo"} ->
          json(%{links: [%{href: "https://example.com/nodeinfo/2.1.json"}]})

        %{method: :get, url: "https://example.com/nodeinfo/2.1.json"} ->
          json(%{metadata: %{features: ["shareable_emoji_packs"]}})

        %{
          method: :get,
          url: "https://example.com/api/pleroma/emoji/pack?name=test_pack"
        } ->
          conn
          |> get("/api/pleroma/emoji/pack?name=test_pack")
          |> json_response_and_validate_schema(200)
          |> json()

        %{
          method: :get,
          url: "https://example.com/api/pleroma/emoji/packs/archive?name=test_pack"
        } ->
          conn
          |> get("/api/pleroma/emoji/packs/archive?name=test_pack")
          |> response(200)
          |> text()

        %{
          method: :get,
          url: "https://example.com/api/pleroma/emoji/pack?name=test_pack_nonshared"
        } ->
          conn
          |> get("/api/pleroma/emoji/pack?name=test_pack_nonshared")
          |> json_response_and_validate_schema(200)
          |> json()

        %{
          method: :get,
          url: "https://nonshared-pack"
        } ->
          text(File.read!("#{@emoji_path}/test_pack_nonshared/nonshared.zip"))
      end)

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/download", %{
               url: "https://example.com",
               name: "test_pack",
               as: "test_pack2"
             })
             |> json_response_and_validate_schema(200) == "ok"

      assert File.exists?("#{@emoji_path}/test_pack2/pack.json")
      assert File.exists?("#{@emoji_path}/test_pack2/blank.png")

      assert admin_conn
             |> delete("/api/pleroma/emoji/pack?name=test_pack2")
             |> json_response_and_validate_schema(200) == "ok"

      refute File.exists?("#{@emoji_path}/test_pack2")

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post(
               "/api/pleroma/emoji/packs/download",
               %{
                 url: "https://example.com",
                 name: "test_pack_nonshared",
                 as: "test_pack_nonshared2"
               }
             )
             |> json_response_and_validate_schema(200) == "ok"

      assert File.exists?("#{@emoji_path}/test_pack_nonshared2/pack.json")
      assert File.exists?("#{@emoji_path}/test_pack_nonshared2/blank.png")

      assert admin_conn
             |> delete("/api/pleroma/emoji/pack?name=test_pack_nonshared2")
             |> json_response_and_validate_schema(200) == "ok"

      refute File.exists?("#{@emoji_path}/test_pack_nonshared2")
    end

    test "nonshareable instance", %{admin_conn: admin_conn} do
      mock(fn
        %{method: :get, url: "https://old-instance/.well-known/nodeinfo"} ->
          json(%{links: [%{href: "https://old-instance/nodeinfo/2.1.json"}]})

        %{method: :get, url: "https://old-instance/nodeinfo/2.1.json"} ->
          json(%{metadata: %{features: []}})
      end)

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post(
               "/api/pleroma/emoji/packs/download",
               %{
                 url: "https://old-instance",
                 name: "test_pack",
                 as: "test_pack2"
               }
             )
             |> json_response_and_validate_schema(500) == %{
               "error" => "The requested instance does not support sharing emoji packs"
             }
    end

    test "checksum fail", %{admin_conn: admin_conn} do
      mock(fn
        %{method: :get, url: "https://example.com/.well-known/nodeinfo"} ->
          json(%{links: [%{href: "https://example.com/nodeinfo/2.1.json"}]})

        %{method: :get, url: "https://example.com/nodeinfo/2.1.json"} ->
          json(%{metadata: %{features: ["shareable_emoji_packs"]}})

        %{
          method: :get,
          url: "https://example.com/api/pleroma/emoji/pack?name=pack_bad_sha"
        } ->
          {:ok, pack} = Pleroma.Emoji.Pack.load_pack("pack_bad_sha")
          %Tesla.Env{status: 200, body: Jason.encode!(pack)}

        %{
          method: :get,
          url: "https://example.com/api/pleroma/emoji/packs/archive?name=pack_bad_sha"
        } ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/instance_static/emoji/pack_bad_sha/pack_bad_sha.zip")
          }
      end)

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/download", %{
               url: "https://example.com",
               name: "pack_bad_sha",
               as: "pack_bad_sha2"
             })
             |> json_response_and_validate_schema(:internal_server_error) == %{
               "error" => "SHA256 for the pack doesn't match the one sent by the server"
             }
    end

    test "other error", %{admin_conn: admin_conn} do
      mock(fn
        %{method: :get, url: "https://example.com/.well-known/nodeinfo"} ->
          json(%{links: [%{href: "https://example.com/nodeinfo/2.1.json"}]})

        %{method: :get, url: "https://example.com/nodeinfo/2.1.json"} ->
          json(%{metadata: %{features: ["shareable_emoji_packs"]}})

        %{
          method: :get,
          url: "https://example.com/api/pleroma/emoji/pack?name=test_pack"
        } ->
          {:ok, pack} = Pleroma.Emoji.Pack.load_pack("test_pack")
          %Tesla.Env{status: 200, body: Jason.encode!(pack)}
      end)

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/download", %{
               url: "https://example.com",
               name: "test_pack",
               as: "test_pack2"
             })
             |> json_response_and_validate_schema(:internal_server_error) == %{
               "error" =>
                 "The pack was not set as shared and there is no fallback src to download from"
             }
    end
  end

  describe "PATCH/update /api/pleroma/emoji/pack?name=:name" do
    setup do
      pack_file = "#{@emoji_path}/test_pack/pack.json"
      original_content = File.read!(pack_file)

      on_exit(fn ->
        File.write!(pack_file, original_content)
      end)

      {:ok,
       pack_file: pack_file,
       new_data: %{
         "license" => "Test license changed",
         "homepage" => "https://pleroma.social",
         "description" => "Test description",
         "share-files" => false
       }}
    end

    test "returns error when file system not writable", %{admin_conn: conn} = ctx do
      with_mocks([
        {File, [:passthrough], [stat: fn _ -> {:error, :eacces} end]}
      ]) do
        assert conn
               |> put_req_header("content-type", "multipart/form-data")
               |> patch(
                 "/api/pleroma/emoji/pack?name=test_pack",
                 %{"metadata" => ctx[:new_data]}
               )
               |> json_response_and_validate_schema(500)
      end
    end

    test "for a pack without a fallback source", ctx do
      assert ctx[:admin_conn]
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/pack?name=test_pack", %{
               "metadata" => ctx[:new_data]
             })
             |> json_response_and_validate_schema(200) == ctx[:new_data]

      assert Jason.decode!(File.read!(ctx[:pack_file]))["pack"] == ctx[:new_data]
    end

    test "for a pack with a fallback source", ctx do
      mock(fn
        %{
          method: :get,
          url: "https://nonshared-pack"
        } ->
          text(File.read!("#{@emoji_path}/test_pack_nonshared/nonshared.zip"))
      end)

      new_data = Map.put(ctx[:new_data], "fallback-src", "https://nonshared-pack")

      new_data_with_sha =
        Map.put(
          new_data,
          "fallback-src-sha256",
          "1967BB4E42BCC34BCC12D57BE7811D3B7BE52F965BCE45C87BD377B9499CE11D"
        )

      assert ctx[:admin_conn]
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/pack?name=test_pack", %{metadata: new_data})
             |> json_response_and_validate_schema(200) == new_data_with_sha

      assert Jason.decode!(File.read!(ctx[:pack_file]))["pack"] == new_data_with_sha
    end

    test "when the fallback source doesn't have all the files", ctx do
      mock(fn
        %{
          method: :get,
          url: "https://nonshared-pack"
        } ->
          {:ok, {'empty.zip', empty_arch}} = :zip.zip('empty.zip', [], [:memory])
          text(empty_arch)
      end)

      new_data = Map.put(ctx[:new_data], "fallback-src", "https://nonshared-pack")

      assert ctx[:admin_conn]
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/pack?name=test_pack", %{metadata: new_data})
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "The fallback archive does not have all files specified in pack.json"
             }
    end
  end

  describe "POST/DELETE /api/pleroma/emoji/pack?name=:name" do
    test "returns an error on creates pack when file system not writable", %{
      admin_conn: admin_conn
    } do
      path_pack = Path.join(@emoji_path, "test_pack")

      with_mocks([
        {File, [:passthrough], [mkdir: fn ^path_pack -> {:error, :eacces} end]}
      ]) do
        assert admin_conn
               |> post("/api/pleroma/emoji/pack?name=test_pack")
               |> json_response_and_validate_schema(500) == %{
                 "error" =>
                   "Unexpected error occurred while creating pack. (POSIX error: Permission denied)"
               }
      end
    end

    test "returns an error on deletes pack when the file system is not writable", %{
      admin_conn: admin_conn
    } do
      path_pack = Path.join(@emoji_path, "test_emoji_pack")

      try do
        {:ok, _pack} = Pleroma.Emoji.Pack.create("test_emoji_pack")

        with_mocks([
          {File, [:passthrough], [rm_rf: fn ^path_pack -> {:error, :eacces, path_pack} end]}
        ]) do
          assert admin_conn
                 |> delete("/api/pleroma/emoji/pack?name=test_emoji_pack")
                 |> json_response_and_validate_schema(500) == %{
                   "error" =>
                     "Couldn't delete the `test_emoji_pack` pack (POSIX error: Permission denied)"
                 }
        end
      after
        File.rm_rf(path_pack)
      end
    end

    test "creating and deleting a pack", %{admin_conn: admin_conn} do
      assert admin_conn
             |> post("/api/pleroma/emoji/pack?name=test_created")
             |> json_response_and_validate_schema(200) == "ok"

      assert File.exists?("#{@emoji_path}/test_created/pack.json")

      assert Jason.decode!(File.read!("#{@emoji_path}/test_created/pack.json")) == %{
               "pack" => %{},
               "files" => %{},
               "files_count" => 0
             }

      assert admin_conn
             |> delete("/api/pleroma/emoji/pack?name=test_created")
             |> json_response_and_validate_schema(200) == "ok"

      refute File.exists?("#{@emoji_path}/test_created/pack.json")
    end

    test "if pack exists", %{admin_conn: admin_conn} do
      path = Path.join(@emoji_path, "test_created")
      File.mkdir(path)
      pack_file = Jason.encode!(%{files: %{}, pack: %{}})
      File.write!(Path.join(path, "pack.json"), pack_file)

      assert admin_conn
             |> post("/api/pleroma/emoji/pack?name=test_created")
             |> json_response_and_validate_schema(:conflict) == %{
               "error" => "A pack named \"test_created\" already exists"
             }

      on_exit(fn -> File.rm_rf(path) end)
    end

    test "with empty name", %{admin_conn: admin_conn} do
      assert admin_conn
             |> post("/api/pleroma/emoji/pack?name= ")
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "pack name cannot be empty"
             }
    end
  end

  test "deleting nonexisting pack", %{admin_conn: admin_conn} do
    assert admin_conn
           |> delete("/api/pleroma/emoji/pack?name=non_existing")
           |> json_response_and_validate_schema(:not_found) == %{
             "error" => "Pack non_existing does not exist"
           }
  end

  test "deleting with empty name", %{admin_conn: admin_conn} do
    assert admin_conn
           |> delete("/api/pleroma/emoji/pack?name= ")
           |> json_response_and_validate_schema(:bad_request) == %{
             "error" => "pack name cannot be empty"
           }
  end

  test "filesystem import", %{admin_conn: admin_conn, conn: conn} do
    on_exit(fn ->
      File.rm!("#{@emoji_path}/test_pack_for_import/emoji.txt")
      File.rm!("#{@emoji_path}/test_pack_for_import/pack.json")
    end)

    resp = conn |> get("/api/pleroma/emoji/packs") |> json_response_and_validate_schema(200)

    refute Map.has_key?(resp["packs"], "test_pack_for_import")

    assert admin_conn
           |> get("/api/pleroma/emoji/packs/import")
           |> json_response_and_validate_schema(200) == ["test_pack_for_import"]

    resp = conn |> get("/api/pleroma/emoji/packs") |> json_response_and_validate_schema(200)
    assert resp["packs"]["test_pack_for_import"]["files"] == %{"blank" => "blank.png"}

    File.rm!("#{@emoji_path}/test_pack_for_import/pack.json")
    refute File.exists?("#{@emoji_path}/test_pack_for_import/pack.json")

    emoji_txt_content = """
    blank, blank.png, Fun
    blank2, blank.png
    foo, /emoji/test_pack_for_import/blank.png
    bar
    """

    File.write!("#{@emoji_path}/test_pack_for_import/emoji.txt", emoji_txt_content)

    assert admin_conn
           |> get("/api/pleroma/emoji/packs/import")
           |> json_response_and_validate_schema(200) == ["test_pack_for_import"]

    resp = conn |> get("/api/pleroma/emoji/packs") |> json_response_and_validate_schema(200)

    assert resp["packs"]["test_pack_for_import"]["files"] == %{
             "blank" => "blank.png",
             "blank2" => "blank.png",
             "foo" => "blank.png"
           }
  end

  describe "GET /api/pleroma/emoji/pack?name=:name" do
    test "shows pack.json", %{conn: conn} do
      assert %{
               "files" => files,
               "files_count" => 2,
               "pack" => %{
                 "can-download" => true,
                 "description" => "Test description",
                 "download-sha256" => _,
                 "homepage" => "https://pleroma.social",
                 "license" => "Test license",
                 "share-files" => true
               }
             } =
               conn
               |> get("/api/pleroma/emoji/pack?name=test_pack")
               |> json_response_and_validate_schema(200)

      assert files == %{"blank" => "blank.png", "blank2" => "blank2.png"}

      assert %{
               "files" => files,
               "files_count" => 2
             } =
               conn
               |> get("/api/pleroma/emoji/pack?name=test_pack&page_size=1")
               |> json_response_and_validate_schema(200)

      assert files |> Map.keys() |> length() == 1

      assert %{
               "files" => files,
               "files_count" => 2
             } =
               conn
               |> get("/api/pleroma/emoji/pack?name=test_pack&page_size=1&page=2")
               |> json_response_and_validate_schema(200)

      assert files |> Map.keys() |> length() == 1
    end

    test "for pack name with special chars", %{conn: conn} do
      assert %{
               "files" => _files,
               "files_count" => 1,
               "pack" => %{
                 "can-download" => true,
                 "description" => "Test description",
                 "download-sha256" => _,
                 "homepage" => "https://pleroma.social",
                 "license" => "Test license",
                 "share-files" => true
               }
             } =
               conn
               |> get("/api/pleroma/emoji/pack?name=blobs.gg")
               |> json_response_and_validate_schema(200)
    end

    test "non existing pack", %{conn: conn} do
      assert conn
             |> get("/api/pleroma/emoji/pack?name=non_existing")
             |> json_response_and_validate_schema(:not_found) == %{
               "error" => "Pack non_existing does not exist"
             }
    end

    test "error name", %{conn: conn} do
      assert conn
             |> get("/api/pleroma/emoji/pack?name= ")
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "pack name cannot be empty"
             }
    end
  end
end
