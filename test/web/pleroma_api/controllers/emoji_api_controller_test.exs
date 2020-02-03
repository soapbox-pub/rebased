# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EmojiAPIControllerTest do
  use Pleroma.Web.ConnCase

  import Tesla.Mock
  import Pleroma.Factory

  @emoji_dir_path Path.join(
                    Pleroma.Config.get!([:instance, :static_dir]),
                    "emoji"
                  )

  clear_config([:auth, :enforce_oauth_admin_scope_usage]) do
    Pleroma.Config.put([:auth, :enforce_oauth_admin_scope_usage], false)
  end

  test "shared & non-shared pack information in list_packs is ok" do
    conn = build_conn()
    resp = conn |> get(emoji_api_path(conn, :list_packs)) |> json_response(200)

    assert Map.has_key?(resp, "test_pack")

    pack = resp["test_pack"]

    assert Map.has_key?(pack["pack"], "download-sha256")
    assert pack["pack"]["can-download"]

    assert pack["files"] == %{"blank" => "blank.png"}

    # Non-shared pack

    assert Map.has_key?(resp, "test_pack_nonshared")

    pack = resp["test_pack_nonshared"]

    refute pack["pack"]["shared"]
    refute pack["pack"]["can-download"]
  end

  test "listing remote packs" do
    admin = insert(:user, is_admin: true)
    %{conn: conn} = oauth_access(["admin:write"], user: admin)

    resp =
      build_conn()
      |> get(emoji_api_path(conn, :list_packs))
      |> json_response(200)

    mock(fn
      %{method: :get, url: "https://example.com/.well-known/nodeinfo"} ->
        json(%{links: [%{href: "https://example.com/nodeinfo/2.1.json"}]})

      %{method: :get, url: "https://example.com/nodeinfo/2.1.json"} ->
        json(%{metadata: %{features: ["shareable_emoji_packs"]}})

      %{method: :get, url: "https://example.com/api/pleroma/emoji/packs"} ->
        json(resp)
    end)

    assert conn
           |> post(emoji_api_path(conn, :list_from), %{instance_address: "https://example.com"})
           |> json_response(200) == resp
  end

  test "downloading a shared pack from download_shared" do
    conn = build_conn()

    resp =
      conn
      |> get(emoji_api_path(conn, :download_shared, "test_pack"))
      |> response(200)

    {:ok, arch} = :zip.unzip(resp, [:memory])

    assert Enum.find(arch, fn {n, _} -> n == 'pack.json' end)
    assert Enum.find(arch, fn {n, _} -> n == 'blank.png' end)
  end

  test "downloading shared & unshared packs from another instance via download_from, deleting them" do
    on_exit(fn ->
      File.rm_rf!("#{@emoji_dir_path}/test_pack2")
      File.rm_rf!("#{@emoji_dir_path}/test_pack_nonshared2")
    end)

    mock(fn
      %{method: :get, url: "https://old-instance/.well-known/nodeinfo"} ->
        json(%{links: [%{href: "https://old-instance/nodeinfo/2.1.json"}]})

      %{method: :get, url: "https://old-instance/nodeinfo/2.1.json"} ->
        json(%{metadata: %{features: []}})

      %{method: :get, url: "https://example.com/.well-known/nodeinfo"} ->
        json(%{links: [%{href: "https://example.com/nodeinfo/2.1.json"}]})

      %{method: :get, url: "https://example.com/nodeinfo/2.1.json"} ->
        json(%{metadata: %{features: ["shareable_emoji_packs"]}})

      %{
        method: :get,
        url: "https://example.com/api/pleroma/emoji/packs/list"
      } ->
        conn = build_conn()

        conn
        |> get(emoji_api_path(conn, :list_packs))
        |> json_response(200)
        |> json()

      %{
        method: :get,
        url: "https://example.com/api/pleroma/emoji/packs/download_shared/test_pack"
      } ->
        conn = build_conn()

        conn
        |> get(emoji_api_path(conn, :download_shared, "test_pack"))
        |> response(200)
        |> text()

      %{
        method: :get,
        url: "https://nonshared-pack"
      } ->
        text(File.read!("#{@emoji_dir_path}/test_pack_nonshared/nonshared.zip"))
    end)

    admin = insert(:user, is_admin: true)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, insert(:oauth_admin_token, user: admin, scopes: ["admin:write"]))

    assert (conn
            |> put_req_header("content-type", "application/json")
            |> post(
              emoji_api_path(
                conn,
                :download_from
              ),
              %{
                instance_address: "https://old-instance",
                pack_name: "test_pack",
                as: "test_pack2"
              }
              |> Jason.encode!()
            )
            |> json_response(500))["error"] =~ "does not support"

    assert conn
           |> put_req_header("content-type", "application/json")
           |> post(
             emoji_api_path(
               conn,
               :download_from
             ),
             %{
               instance_address: "https://example.com",
               pack_name: "test_pack",
               as: "test_pack2"
             }
             |> Jason.encode!()
           )
           |> json_response(200) == "ok"

    assert File.exists?("#{@emoji_dir_path}/test_pack2/pack.json")
    assert File.exists?("#{@emoji_dir_path}/test_pack2/blank.png")

    assert conn
           |> delete(emoji_api_path(conn, :delete, "test_pack2"))
           |> json_response(200) == "ok"

    refute File.exists?("#{@emoji_dir_path}/test_pack2")

    # non-shared, downloaded from the fallback URL

    assert conn
           |> put_req_header("content-type", "application/json")
           |> post(
             emoji_api_path(
               conn,
               :download_from
             ),
             %{
               instance_address: "https://example.com",
               pack_name: "test_pack_nonshared",
               as: "test_pack_nonshared2"
             }
             |> Jason.encode!()
           )
           |> json_response(200) == "ok"

    assert File.exists?("#{@emoji_dir_path}/test_pack_nonshared2/pack.json")
    assert File.exists?("#{@emoji_dir_path}/test_pack_nonshared2/blank.png")

    assert conn
           |> delete(emoji_api_path(conn, :delete, "test_pack_nonshared2"))
           |> json_response(200) == "ok"

    refute File.exists?("#{@emoji_dir_path}/test_pack_nonshared2")
  end

  describe "updating pack metadata" do
    setup do
      pack_file = "#{@emoji_dir_path}/test_pack/pack.json"
      original_content = File.read!(pack_file)

      on_exit(fn ->
        File.write!(pack_file, original_content)
      end)

      admin = insert(:user, is_admin: true)
      %{conn: conn} = oauth_access(["admin:write"], user: admin)

      {:ok,
       admin: admin,
       conn: conn,
       pack_file: pack_file,
       new_data: %{
         "license" => "Test license changed",
         "homepage" => "https://pleroma.social",
         "description" => "Test description",
         "share-files" => false
       }}
    end

    test "for a pack without a fallback source", ctx do
      conn = ctx[:conn]

      assert conn
             |> post(
               emoji_api_path(conn, :update_metadata, "test_pack"),
               %{
                 "new_data" => ctx[:new_data]
               }
             )
             |> json_response(200) == ctx[:new_data]

      assert Jason.decode!(File.read!(ctx[:pack_file]))["pack"] == ctx[:new_data]
    end

    test "for a pack with a fallback source", ctx do
      mock(fn
        %{
          method: :get,
          url: "https://nonshared-pack"
        } ->
          text(File.read!("#{@emoji_dir_path}/test_pack_nonshared/nonshared.zip"))
      end)

      new_data = Map.put(ctx[:new_data], "fallback-src", "https://nonshared-pack")

      new_data_with_sha =
        Map.put(
          new_data,
          "fallback-src-sha256",
          "74409E2674DAA06C072729C6C8426C4CB3B7E0B85ED77792DB7A436E11D76DAF"
        )

      conn = ctx[:conn]

      assert conn
             |> post(
               emoji_api_path(conn, :update_metadata, "test_pack"),
               %{
                 "new_data" => new_data
               }
             )
             |> json_response(200) == new_data_with_sha

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

      conn = ctx[:conn]

      assert (conn
              |> post(
                emoji_api_path(conn, :update_metadata, "test_pack"),
                %{
                  "new_data" => new_data
                }
              )
              |> json_response(:bad_request))["error"] =~ "does not have all"
    end
  end

  test "updating pack files" do
    pack_file = "#{@emoji_dir_path}/test_pack/pack.json"
    original_content = File.read!(pack_file)

    on_exit(fn ->
      File.write!(pack_file, original_content)

      File.rm_rf!("#{@emoji_dir_path}/test_pack/blank_url.png")
      File.rm_rf!("#{@emoji_dir_path}/test_pack/dir")
      File.rm_rf!("#{@emoji_dir_path}/test_pack/dir_2")
    end)

    admin = insert(:user, is_admin: true)
    %{conn: conn} = oauth_access(["admin:write"], user: admin)

    same_name = %{
      "action" => "add",
      "shortcode" => "blank",
      "filename" => "dir/blank.png",
      "file" => %Plug.Upload{
        filename: "blank.png",
        path: "#{@emoji_dir_path}/test_pack/blank.png"
      }
    }

    different_name = %{same_name | "shortcode" => "blank_2"}

    assert (conn
            |> post(emoji_api_path(conn, :update_file, "test_pack"), same_name)
            |> json_response(:conflict))["error"] =~ "already exists"

    assert conn
           |> post(emoji_api_path(conn, :update_file, "test_pack"), different_name)
           |> json_response(200) == %{"blank" => "blank.png", "blank_2" => "dir/blank.png"}

    assert File.exists?("#{@emoji_dir_path}/test_pack/dir/blank.png")

    assert conn
           |> post(emoji_api_path(conn, :update_file, "test_pack"), %{
             "action" => "update",
             "shortcode" => "blank_2",
             "new_shortcode" => "blank_3",
             "new_filename" => "dir_2/blank_3.png"
           })
           |> json_response(200) == %{"blank" => "blank.png", "blank_3" => "dir_2/blank_3.png"}

    refute File.exists?("#{@emoji_dir_path}/test_pack/dir/")
    assert File.exists?("#{@emoji_dir_path}/test_pack/dir_2/blank_3.png")

    assert conn
           |> post(emoji_api_path(conn, :update_file, "test_pack"), %{
             "action" => "remove",
             "shortcode" => "blank_3"
           })
           |> json_response(200) == %{"blank" => "blank.png"}

    refute File.exists?("#{@emoji_dir_path}/test_pack/dir_2/")

    mock(fn
      %{
        method: :get,
        url: "https://test-blank/blank_url.png"
      } ->
        text(File.read!("#{@emoji_dir_path}/test_pack/blank.png"))
    end)

    # The name should be inferred from the URL ending
    from_url = %{
      "action" => "add",
      "shortcode" => "blank_url",
      "file" => "https://test-blank/blank_url.png"
    }

    assert conn
           |> post(emoji_api_path(conn, :update_file, "test_pack"), from_url)
           |> json_response(200) == %{
             "blank" => "blank.png",
             "blank_url" => "blank_url.png"
           }

    assert File.exists?("#{@emoji_dir_path}/test_pack/blank_url.png")

    assert conn
           |> post(emoji_api_path(conn, :update_file, "test_pack"), %{
             "action" => "remove",
             "shortcode" => "blank_url"
           })
           |> json_response(200) == %{"blank" => "blank.png"}

    refute File.exists?("#{@emoji_dir_path}/test_pack/blank_url.png")
  end

  test "creating and deleting a pack" do
    on_exit(fn ->
      File.rm_rf!("#{@emoji_dir_path}/test_created")
    end)

    admin = insert(:user, is_admin: true)
    %{conn: conn} = oauth_access(["admin:write"], user: admin)

    assert conn
           |> put_req_header("content-type", "application/json")
           |> put(
             emoji_api_path(
               conn,
               :create,
               "test_created"
             )
           )
           |> json_response(200) == "ok"

    assert File.exists?("#{@emoji_dir_path}/test_created/pack.json")

    assert Jason.decode!(File.read!("#{@emoji_dir_path}/test_created/pack.json")) == %{
             "pack" => %{},
             "files" => %{}
           }

    assert conn
           |> delete(emoji_api_path(conn, :delete, "test_created"))
           |> json_response(200) == "ok"

    refute File.exists?("#{@emoji_dir_path}/test_created/pack.json")
  end

  test "filesystem import" do
    on_exit(fn ->
      File.rm!("#{@emoji_dir_path}/test_pack_for_import/emoji.txt")
      File.rm!("#{@emoji_dir_path}/test_pack_for_import/pack.json")
    end)

    conn = build_conn()
    resp = conn |> get(emoji_api_path(conn, :list_packs)) |> json_response(200)

    refute Map.has_key?(resp, "test_pack_for_import")

    admin = insert(:user, is_admin: true)
    %{conn: conn} = oauth_access(["admin:write"], user: admin)

    assert conn
           |> post(emoji_api_path(conn, :import_from_fs))
           |> json_response(200) == ["test_pack_for_import"]

    resp = conn |> get(emoji_api_path(conn, :list_packs)) |> json_response(200)
    assert resp["test_pack_for_import"]["files"] == %{"blank" => "blank.png"}

    File.rm!("#{@emoji_dir_path}/test_pack_for_import/pack.json")
    refute File.exists?("#{@emoji_dir_path}/test_pack_for_import/pack.json")

    emoji_txt_content = "blank, blank.png, Fun\n\nblank2, blank.png"

    File.write!("#{@emoji_dir_path}/test_pack_for_import/emoji.txt", emoji_txt_content)

    assert conn
           |> post(emoji_api_path(conn, :import_from_fs))
           |> json_response(200) == ["test_pack_for_import"]

    resp = build_conn() |> get(emoji_api_path(conn, :list_packs)) |> json_response(200)

    assert resp["test_pack_for_import"]["files"] == %{
             "blank" => "blank.png",
             "blank2" => "blank.png"
           }
  end
end
