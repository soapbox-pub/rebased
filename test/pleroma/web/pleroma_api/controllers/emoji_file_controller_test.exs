# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EmojiFileControllerTest do
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

  describe "POST/PATCH/DELETE /api/pleroma/emoji/packs/files?name=:name" do
    setup do
      clear_config([:instance, :admin_privileges], [:emoji_manage_emoji])
      pack_file = "#{@emoji_path}/test_pack/pack.json"
      original_content = File.read!(pack_file)

      on_exit(fn ->
        File.write!(pack_file, original_content)
      end)

      :ok
    end

    test "upload zip file with emojies", %{admin_conn: admin_conn} do
      on_exit(fn ->
        [
          "128px/a_trusted_friend-128.png",
          "auroraborealis.png",
          "1000px/baby_in_a_box.png",
          "1000px/bear.png",
          "128px/bear-128.png"
        ]
        |> Enum.each(fn path -> File.rm_rf!("#{@emoji_path}/test_pack/#{path}") end)
      end)

      resp =
        admin_conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/emoji/packs/files?name=test_pack", %{
          file: %Plug.Upload{
            content_type: "application/zip",
            filename: "emojis.zip",
            path: Path.absname("test/fixtures/emojis.zip")
          }
        })
        |> json_response_and_validate_schema(200)

      assert resp == %{
               "a_trusted_friend-128" => "128px/a_trusted_friend-128.png",
               "auroraborealis" => "auroraborealis.png",
               "baby_in_a_box" => "1000px/baby_in_a_box.png",
               "bear" => "1000px/bear.png",
               "bear-128" => "128px/bear-128.png",
               "blank" => "blank.png",
               "blank2" => "blank2.png"
             }

      Enum.each(Map.values(resp), fn path ->
        assert File.exists?("#{@emoji_path}/test_pack/#{path}")
      end)
    end

    test "create shortcode exists", %{admin_conn: admin_conn} do
      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/files?name=test_pack", %{
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
             |> post("/api/pleroma/emoji/packs/files?name=test_pack", %{
               shortcode: "blank3",
               filename: "dir/blank.png",
               file: %Plug.Upload{
                 filename: "blank.png",
                 path: "#{@emoji_path}/test_pack/blank.png"
               }
             })
             |> json_response_and_validate_schema(200) == %{
               "blank" => "blank.png",
               "blank2" => "blank2.png",
               "blank3" => "dir/blank.png"
             }

      assert File.exists?("#{@emoji_path}/test_pack/dir/blank.png")

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/packs/files?name=test_pack", %{
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
             |> post("/api/pleroma/emoji/packs/files?name=test_pack", %{
               shortcode: "blank3",
               filename: "dir/blank.png",
               file: %Plug.Upload{
                 filename: "blank.png",
                 path: "#{@emoji_path}/test_pack/blank.png"
               }
             })
             |> json_response_and_validate_schema(200) == %{
               "blank" => "blank.png",
               "blank2" => "blank2.png",
               "blank3" => "dir/blank.png"
             }

      assert File.exists?("#{@emoji_path}/test_pack/dir/blank.png")

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/packs/files?name=test_pack", %{
               shortcode: "blank3",
               new_shortcode: "blank4",
               new_filename: "dir_2/blank_3.png",
               force: true
             })
             |> json_response_and_validate_schema(200) == %{
               "blank" => "blank.png",
               "blank2" => "blank2.png",
               "blank4" => "dir_2/blank_3.png"
             }

      assert File.exists?("#{@emoji_path}/test_pack/dir_2/blank_3.png")
    end

    test "with empty filename", %{admin_conn: admin_conn} do
      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/files?name=test_pack", %{
               shortcode: "blank2",
               filename: "",
               file: %Plug.Upload{
                 filename: "blank.png",
                 path: "#{@emoji_path}/test_pack/blank.png"
               }
             })
             |> json_response_and_validate_schema(422) == %{
               "error" => "pack name, shortcode or filename cannot be empty"
             }
    end

    test "add file with not loaded pack", %{admin_conn: admin_conn} do
      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/files?name=not_loaded", %{
               shortcode: "blank3",
               filename: "dir/blank.png",
               file: %Plug.Upload{
                 filename: "blank.png",
                 path: "#{@emoji_path}/test_pack/blank.png"
               }
             })
             |> json_response_and_validate_schema(:not_found) == %{
               "error" => "pack \"not_loaded\" is not found"
             }
    end

    test "returns an error on add file when file system is not writable", %{
      admin_conn: admin_conn
    } do
      pack_file = Path.join([@emoji_path, "not_loaded", "pack.json"])

      with_mocks([
        {File, [:passthrough], [stat: fn ^pack_file -> {:error, :eacces} end]}
      ]) do
        assert admin_conn
               |> put_req_header("content-type", "multipart/form-data")
               |> post("/api/pleroma/emoji/packs/files?name=not_loaded", %{
                 shortcode: "blank3",
                 filename: "dir/blank.png",
                 file: %Plug.Upload{
                   filename: "blank.png",
                   path: "#{@emoji_path}/test_pack/blank.png"
                 }
               })
               |> json_response_and_validate_schema(500) == %{
                 "error" =>
                   "Unexpected error occurred while adding file to pack. (POSIX error: Permission denied)"
               }
      end
    end

    test "remove file with not loaded pack", %{admin_conn: admin_conn} do
      assert admin_conn
             |> delete("/api/pleroma/emoji/packs/files?name=not_loaded&shortcode=blank3")
             |> json_response_and_validate_schema(:not_found) == %{
               "error" => "pack \"not_loaded\" is not found"
             }
    end

    test "remove file with empty shortcode", %{admin_conn: admin_conn} do
      assert admin_conn
             |> delete("/api/pleroma/emoji/packs/files?name=not_loaded&shortcode=")
             |> json_response_and_validate_schema(:not_found) == %{
               "error" => "pack \"not_loaded\" is not found"
             }
    end

    test "update file with not loaded pack", %{admin_conn: admin_conn} do
      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/packs/files?name=not_loaded", %{
               shortcode: "blank4",
               new_shortcode: "blank3",
               new_filename: "dir_2/blank_3.png"
             })
             |> json_response_and_validate_schema(:not_found) == %{
               "error" => "pack \"not_loaded\" is not found"
             }
    end

    test "new with shortcode as file with update", %{admin_conn: admin_conn} do
      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/files?name=test_pack", %{
               shortcode: "blank4",
               filename: "dir/blank.png",
               file: %Plug.Upload{
                 filename: "blank.png",
                 path: "#{@emoji_path}/test_pack/blank.png"
               }
             })
             |> json_response_and_validate_schema(200) == %{
               "blank" => "blank.png",
               "blank4" => "dir/blank.png",
               "blank2" => "blank2.png"
             }

      assert File.exists?("#{@emoji_path}/test_pack/dir/blank.png")

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/packs/files?name=test_pack", %{
               shortcode: "blank4",
               new_shortcode: "blank3",
               new_filename: "dir_2/blank_3.png"
             })
             |> json_response_and_validate_schema(200) == %{
               "blank3" => "dir_2/blank_3.png",
               "blank" => "blank.png",
               "blank2" => "blank2.png"
             }

      refute File.exists?("#{@emoji_path}/test_pack/dir/")
      assert File.exists?("#{@emoji_path}/test_pack/dir_2/blank_3.png")

      assert admin_conn
             |> delete("/api/pleroma/emoji/packs/files?name=test_pack&shortcode=blank3")
             |> json_response_and_validate_schema(200) == %{
               "blank" => "blank.png",
               "blank2" => "blank2.png"
             }

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
             |> post("/api/pleroma/emoji/packs/files?name=test_pack", %{
               shortcode: "blank_url",
               file: "https://test-blank/blank_url.png"
             })
             |> json_response_and_validate_schema(200) == %{
               "blank_url" => "blank_url.png",
               "blank" => "blank.png",
               "blank2" => "blank2.png"
             }

      assert File.exists?("#{@emoji_path}/test_pack/blank_url.png")

      on_exit(fn -> File.rm_rf!("#{@emoji_path}/test_pack/blank_url.png") end)
    end

    test "new without shortcode", %{admin_conn: admin_conn} do
      on_exit(fn -> File.rm_rf!("#{@emoji_path}/test_pack/shortcode.png") end)

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/files?name=test_pack", %{
               file: %Plug.Upload{
                 filename: "shortcode.png",
                 path: "#{Pleroma.Config.get([:instance, :static_dir])}/add/shortcode.png"
               }
             })
             |> json_response_and_validate_schema(200) == %{
               "shortcode" => "shortcode.png",
               "blank" => "blank.png",
               "blank2" => "blank2.png"
             }
    end

    test "remove non existing shortcode in pack.json", %{admin_conn: admin_conn} do
      assert admin_conn
             |> delete("/api/pleroma/emoji/packs/files?name=test_pack&shortcode=blank3")
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "Emoji \"blank3\" does not exist"
             }
    end

    test "update non existing emoji", %{admin_conn: admin_conn} do
      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/packs/files?name=test_pack", %{
               shortcode: "blank3",
               new_shortcode: "blank4",
               new_filename: "dir_2/blank_3.png"
             })
             |> json_response_and_validate_schema(:bad_request) == %{
               "error" => "Emoji \"blank3\" does not exist"
             }
    end

    test "update with empty shortcode", %{admin_conn: admin_conn} do
      assert %{
               "error" => "Missing field: new_shortcode."
             } =
               admin_conn
               |> put_req_header("content-type", "multipart/form-data")
               |> patch("/api/pleroma/emoji/packs/files?name=test_pack", %{
                 shortcode: "blank",
                 new_filename: "dir_2/blank_3.png"
               })
               |> json_response_and_validate_schema(:bad_request)
    end

    test "it requires privileged role :emoji_manage_emoji", %{admin_conn: admin_conn} do
      clear_config([:instance, :admin_privileges], [])

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> post("/api/pleroma/emoji/packs/files?name=test_pack", %{
               file: %Plug.Upload{
                 filename: "shortcode.png",
                 path: "#{Pleroma.Config.get([:instance, :static_dir])}/add/shortcode.png"
               }
             })
             |> json_response(:forbidden)

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> patch("/api/pleroma/emoji/packs/files?name=test_pack", %{
               shortcode: "blank",
               new_filename: "dir_2/blank_3.png"
             })
             |> json_response(:forbidden)

      assert admin_conn
             |> put_req_header("content-type", "multipart/form-data")
             |> delete("/api/pleroma/emoji/packs/files?name=test_pack&shortcode=blank3")
             |> json_response(:forbidden)
    end
  end
end
