# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EmojiAPIControllerTest do
  use Pleroma.Web.ConnCase

  import Tesla.Mock
  import Pleroma.Factory

  @emoji_path Path.join(
                Pleroma.Config.get!([:instance, :static_dir]),
                "emoji"
              )
  setup do: clear_config([:auth, :enforce_oauth_admin_scope_usage], false)

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

  test "GET /api/pleroma/emoji/packs", %{conn: conn} do
    resp = conn |> get("/api/pleroma/emoji/packs") |> json_response_and_validate_schema(200)

    shared = resp["test_pack"]
    assert shared["files"] == %{"blank" => "blank.png"}
    assert Map.has_key?(shared["pack"], "download-sha256")
    assert shared["pack"]["can-download"]
    assert shared["pack"]["share-files"]

    non_shared = resp["test_pack_nonshared"]
    assert non_shared["pack"]["share-files"] == false
    assert non_shared["pack"]["can-download"] == false
  end

  describe "GET /api/pleroma/emoji/packs/remote" do
    test "shareable instance", %{admin_conn: admin_conn, conn: conn} do
      resp =
        conn
        |> get("/api/pleroma/emoji/packs")
        |> json_response_and_validate_schema(200)

      mock(fn
        %{method: :get, url: "https://example.com/.well-known/nodeinfo"} ->
          json(%{links: [%{href: "https://example.com/nodeinfo/2.1.json"}]})

        %{method: :get, url: "https://example.com/nodeinfo/2.1.json"} ->
          json(%{metadata: %{features: ["shareable_emoji_packs"]}})

        %{method: :get, url: "https://example.com/api/pleroma/emoji/packs"} ->
          json(resp)
      end)

      assert admin_conn
             |> get("/api/pleroma/emoji/packs/remote?url=https://example.com")
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

  describe "GET /api/pleroma/emoji/packs/:name/archive" do
    test "download shared pack", %{conn: conn} do
      resp =
        conn
        |> get("/api/pleroma/emoji/packs/test_pack/archive")
        |> response(200)

      {:ok, arch} = :zip.unzip(resp, [:memory])

      assert Enum.find(arch, fn {n, _} -> n == 'pack.json' end)
      assert Enum.find(arch, fn {n, _} -> n == 'blank.png' end)
    end

    test "non existing pack", %{conn: conn} do
      assert conn
             |> get("/api/pleroma/emoji/packs/test_pack_for_import/archive")
             |> json_response_and_validate_schema(:not_found) == %{
               "error" => "Pack test_pack_for_import does not exist"
             }
    end

    test "non downloadable pack", %{conn: conn} do
      assert conn
             |> get("/api/pleroma/emoji/packs/test_pack_nonshared/archive")
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
          url: "https://example.com/api/pleroma/emoji/packs/test_pack"
        } ->
          conn
          |> get("/api/pleroma/emoji/packs/test_pack")
          |> json_response_and_validate_schema(200)
          |> json()

        %{
          method: :get,
          url: "https://example.com/api/pleroma/emoji/packs/test_pack/archive"
        } ->
          conn
          |> get("/api/pleroma/emoji/packs/test_pack/archive")
          |> response(200)
          |> text()

        %{
          method: :get,
          url: "https://example.com/api/pleroma/emoji/packs/test_pack_nonshared"
        } ->
          conn
          |> get("/api/pleroma/emoji/packs/test_pack_nonshared")
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
             |> delete("/api/pleroma/emoji/packs/test_pack2")
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
             |> delete("/api/pleroma/emoji/packs/test_pack_nonshared2")
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
          url: "https://example.com/api/pleroma/emoji/packs/pack_bad_sha"
        } ->
          {:ok, pack} = Pleroma.Emoji.Pack.load_pack("pack_bad_sha")
          %Tesla.Env{status: 200, body: Jason.encode!(pack)}

        %{
          method: :get,
          url: "https://example.com/api/pleroma/emoji/packs/pack_bad_sha/archive"
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
          url: "https://example.com/api/pleroma/emoji/packs/test_pack"
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

  describe "PATCH /api/pleroma/emoji/packs/:name" do
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

    test "for a pack without a fallback source", ctx do
      assert ctx[:admin_conn]
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/packs/test_pack", %{"metadata" => ctx[:new_data]})
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
          "74409E2674DAA06C072729C6C8426C4CB3B7E0B85ED77792DB7A436E11D76DAF"
        )

      assert ctx[:admin_conn]
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/packs/test_pack", %{metadata: new_data})
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
             |> patch("/api/pleroma/emoji/packs/test_pack", %{metadata: new_data})
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "The fallback archive does not have all files specified in pack.json"
             }
    end
  end

  describe "POST/PATCH/DELETE /api/pleroma/emoji/packs/:name/files" do
    setup do
      pack_file = "#{@emoji_path}/test_pack/pack.json"
      original_content = File.read!(pack_file)

      on_exit(fn ->
        File.write!(pack_file, original_content)
      end)

      :ok
    end

    test "create shortcode exists", %{admin_conn: admin_conn} do
      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/test_pack/files", %{
               shortcode: "blank",
               filename: "dir/blank.png",
               file: %Plug.Upload{
                 filename: "blank.png",
                 path: "#{@emoji_path}/test_pack/blank.png"
               }
             })
             |> json_response_and_validate_schema(:conflict) == %{
               "error" => "An emoji with the \"blank\" shortcode already exists"
             }
    end

    test "don't rewrite old emoji", %{admin_conn: admin_conn} do
      on_exit(fn -> File.rm_rf!("#{@emoji_path}/test_pack/dir/") end)

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/test_pack/files", %{
               shortcode: "blank2",
               filename: "dir/blank.png",
               file: %Plug.Upload{
                 filename: "blank.png",
                 path: "#{@emoji_path}/test_pack/blank.png"
               }
             })
             |> json_response_and_validate_schema(200) == %{
               "blank" => "blank.png",
               "blank2" => "dir/blank.png"
             }

      assert File.exists?("#{@emoji_path}/test_pack/dir/blank.png")

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/packs/test_pack/files", %{
               shortcode: "blank",
               new_shortcode: "blank2",
               new_filename: "dir_2/blank_3.png"
             })
             |> json_response_and_validate_schema(:conflict) == %{
               "error" =>
                 "New shortcode \"blank2\" is already used. If you want to override emoji use 'force' option"
             }
    end

    test "rewrite old emoji with force option", %{admin_conn: admin_conn} do
      on_exit(fn -> File.rm_rf!("#{@emoji_path}/test_pack/dir_2/") end)

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/test_pack/files", %{
               shortcode: "blank2",
               filename: "dir/blank.png",
               file: %Plug.Upload{
                 filename: "blank.png",
                 path: "#{@emoji_path}/test_pack/blank.png"
               }
             })
             |> json_response_and_validate_schema(200) == %{
               "blank" => "blank.png",
               "blank2" => "dir/blank.png"
             }

      assert File.exists?("#{@emoji_path}/test_pack/dir/blank.png")

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/packs/test_pack/files", %{
               shortcode: "blank2",
               new_shortcode: "blank3",
               new_filename: "dir_2/blank_3.png",
               force: true
             })
             |> json_response_and_validate_schema(200) == %{
               "blank" => "blank.png",
               "blank3" => "dir_2/blank_3.png"
             }

      assert File.exists?("#{@emoji_path}/test_pack/dir_2/blank_3.png")
    end

    test "with empty filename", %{admin_conn: admin_conn} do
      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/test_pack/files", %{
               shortcode: "blank2",
               filename: "",
               file: %Plug.Upload{
                 filename: "blank.png",
                 path: "#{@emoji_path}/test_pack/blank.png"
               }
             })
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "pack name, shortcode or filename cannot be empty"
             }
    end

    test "add file with not loaded pack", %{admin_conn: admin_conn} do
      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/not_loaded/files", %{
               shortcode: "blank2",
               filename: "dir/blank.png",
               file: %Plug.Upload{
                 filename: "blank.png",
                 path: "#{@emoji_path}/test_pack/blank.png"
               }
             })
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "pack \"not_loaded\" is not found"
             }
    end

    test "remove file with not loaded pack", %{admin_conn: admin_conn} do
      assert admin_conn
             |> delete("/api/pleroma/emoji/packs/not_loaded/files?shortcode=blank3")
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "pack \"not_loaded\" is not found"
             }
    end

    test "remove file with empty shortcode", %{admin_conn: admin_conn} do
      assert admin_conn
             |> delete("/api/pleroma/emoji/packs/not_loaded/files?shortcode=")
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "pack name or shortcode cannot be empty"
             }
    end

    test "update file with not loaded pack", %{admin_conn: admin_conn} do
      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/packs/not_loaded/files", %{
               shortcode: "blank4",
               new_shortcode: "blank3",
               new_filename: "dir_2/blank_3.png"
             })
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "pack \"not_loaded\" is not found"
             }
    end

    test "new with shortcode as file with update", %{admin_conn: admin_conn} do
      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/test_pack/files", %{
               shortcode: "blank4",
               filename: "dir/blank.png",
               file: %Plug.Upload{
                 filename: "blank.png",
                 path: "#{@emoji_path}/test_pack/blank.png"
               }
             })
             |> json_response_and_validate_schema(200) == %{
               "blank" => "blank.png",
               "blank4" => "dir/blank.png"
             }

      assert File.exists?("#{@emoji_path}/test_pack/dir/blank.png")

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/packs/test_pack/files", %{
               shortcode: "blank4",
               new_shortcode: "blank3",
               new_filename: "dir_2/blank_3.png"
             })
             |> json_response_and_validate_schema(200) == %{
               "blank3" => "dir_2/blank_3.png",
               "blank" => "blank.png"
             }

      refute File.exists?("#{@emoji_path}/test_pack/dir/")
      assert File.exists?("#{@emoji_path}/test_pack/dir_2/blank_3.png")

      assert admin_conn
             |> delete("/api/pleroma/emoji/packs/test_pack/files?shortcode=blank3")
             |> json_response_and_validate_schema(200) == %{"blank" => "blank.png"}

      refute File.exists?("#{@emoji_path}/test_pack/dir_2/")

      on_exit(fn -> File.rm_rf!("#{@emoji_path}/test_pack/dir") end)
    end

    test "new with shortcode from url", %{admin_conn: admin_conn} do
      mock(fn
        %{
          method: :get,
          url: "https://test-blank/blank_url.png"
        } ->
          text(File.read!("#{@emoji_path}/test_pack/blank.png"))
      end)

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/test_pack/files", %{
               shortcode: "blank_url",
               file: "https://test-blank/blank_url.png"
             })
             |> json_response_and_validate_schema(200) == %{
               "blank_url" => "blank_url.png",
               "blank" => "blank.png"
             }

      assert File.exists?("#{@emoji_path}/test_pack/blank_url.png")

      on_exit(fn -> File.rm_rf!("#{@emoji_path}/test_pack/blank_url.png") end)
    end

    test "new without shortcode", %{admin_conn: admin_conn} do
      on_exit(fn -> File.rm_rf!("#{@emoji_path}/test_pack/shortcode.png") end)

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/test_pack/files", %{
               file: %Plug.Upload{
                 filename: "shortcode.png",
                 path: "#{Pleroma.Config.get([:instance, :static_dir])}/add/shortcode.png"
               }
             })
             |> json_response_and_validate_schema(200) == %{
               "shortcode" => "shortcode.png",
               "blank" => "blank.png"
             }
    end

    test "remove non existing shortcode in pack.json", %{admin_conn: admin_conn} do
      assert admin_conn
             |> delete("/api/pleroma/emoji/packs/test_pack/files?shortcode=blank2")
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "Emoji \"blank2\" does not exist"
             }
    end

    test "update non existing emoji", %{admin_conn: admin_conn} do
      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/packs/test_pack/files", %{
               shortcode: "blank2",
               new_shortcode: "blank3",
               new_filename: "dir_2/blank_3.png"
             })
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "Emoji \"blank2\" does not exist"
             }
    end

    test "update with empty shortcode", %{admin_conn: admin_conn} do
      assert %{
               "error" => "Missing field: new_shortcode."
             } =
               admin_conn
               |> put_req_header("content-type", "multipart/form-data")
               |> patch("/api/pleroma/emoji/packs/test_pack/files", %{
                 shortcode: "blank",
                 new_filename: "dir_2/blank_3.png"
               })
               |> json_response_and_validate_schema(:bad_request)
    end
  end

  describe "POST/DELETE /api/pleroma/emoji/packs/:name" do
    test "creating and deleting a pack", %{admin_conn: admin_conn} do
      assert admin_conn
             |> post("/api/pleroma/emoji/packs/test_created")
             |> json_response_and_validate_schema(200) == "ok"

      assert File.exists?("#{@emoji_path}/test_created/pack.json")

      assert Jason.decode!(File.read!("#{@emoji_path}/test_created/pack.json")) == %{
               "pack" => %{},
               "files" => %{}
             }

      assert admin_conn
             |> delete("/api/pleroma/emoji/packs/test_created")
             |> json_response_and_validate_schema(200) == "ok"

      refute File.exists?("#{@emoji_path}/test_created/pack.json")
    end

    test "if pack exists", %{admin_conn: admin_conn} do
      path = Path.join(@emoji_path, "test_created")
      File.mkdir(path)
      pack_file = Jason.encode!(%{files: %{}, pack: %{}})
      File.write!(Path.join(path, "pack.json"), pack_file)

      assert admin_conn
             |> post("/api/pleroma/emoji/packs/test_created")
             |> json_response_and_validate_schema(:conflict) == %{
               "error" => "A pack named \"test_created\" already exists"
             }

      on_exit(fn -> File.rm_rf(path) end)
    end

    test "with empty name", %{admin_conn: admin_conn} do
      assert admin_conn
             |> post("/api/pleroma/emoji/packs/ ")
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "pack name cannot be empty"
             }
    end
  end

  test "deleting nonexisting pack", %{admin_conn: admin_conn} do
    assert admin_conn
           |> delete("/api/pleroma/emoji/packs/non_existing")
           |> json_response_and_validate_schema(:not_found) == %{
             "error" => "Pack non_existing does not exist"
           }
  end

  test "deleting with empty name", %{admin_conn: admin_conn} do
    assert admin_conn
           |> delete("/api/pleroma/emoji/packs/ ")
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

    refute Map.has_key?(resp, "test_pack_for_import")

    assert admin_conn
           |> get("/api/pleroma/emoji/packs/import")
           |> json_response_and_validate_schema(200) == ["test_pack_for_import"]

    resp = conn |> get("/api/pleroma/emoji/packs") |> json_response_and_validate_schema(200)
    assert resp["test_pack_for_import"]["files"] == %{"blank" => "blank.png"}

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

    assert resp["test_pack_for_import"]["files"] == %{
             "blank" => "blank.png",
             "blank2" => "blank.png",
             "foo" => "blank.png"
           }
  end

  describe "GET /api/pleroma/emoji/packs/:name" do
    test "shows pack.json", %{conn: conn} do
      assert %{
               "files" => %{"blank" => "blank.png"},
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
               |> get("/api/pleroma/emoji/packs/test_pack")
               |> json_response_and_validate_schema(200)
    end

    test "non existing pack", %{conn: conn} do
      assert conn
             |> get("/api/pleroma/emoji/packs/non_existing")
             |> json_response_and_validate_schema(:not_found) == %{
               "error" => "Pack non_existing does not exist"
             }
    end

    test "error name", %{conn: conn} do
      assert conn
             |> get("/api/pleroma/emoji/packs/ ")
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "pack name cannot be empty"
             }
    end
  end
end
