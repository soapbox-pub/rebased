# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emoji.PackTest do
  use Pleroma.DataCase
  alias Pleroma.Emoji.Pack

  @emoji_path Path.join(
                Pleroma.Config.get!([:instance, :static_dir]),
                "emoji"
              )

  setup do
    pack_path = Path.join(@emoji_path, "dump_pack")
    File.mkdir(pack_path)

    File.write!(Path.join(pack_path, "pack.json"), """
    {
    "files": { },
    "pack": {
    "description": "Dump pack", "homepage": "https://pleroma.social",
    "license": "Test license", "share-files": true
    }}
    """)

    {:ok, pack} = Pleroma.Emoji.Pack.load_pack("dump_pack")

    on_exit(fn ->
      File.rm_rf!(pack_path)
    end)

    {:ok, pack: pack}
  end

  describe "add_file/4" do
    test "add emojies from zip file", %{pack: pack} do
      file = %Plug.Upload{
        content_type: "application/zip",
        filename: "emojis.zip",
        path: Path.absname("test/fixtures/emojis.zip")
      }

      {:ok, updated_pack} = Pack.add_file(pack, nil, nil, file)

      assert updated_pack.files == %{
               "a_trusted_friend-128" => "128px/a_trusted_friend-128.png",
               "auroraborealis" => "auroraborealis.png",
               "baby_in_a_box" => "1000px/baby_in_a_box.png",
               "bear" => "1000px/bear.png",
               "bear-128" => "128px/bear-128.png"
             }

      assert updated_pack.files_count == 5
    end
  end

  test "returns error when zip file is bad", %{pack: pack} do
    file = %Plug.Upload{
      content_type: "application/zip",
      filename: "emojis.zip",
      path: Path.absname("test/instance_static/emoji/test_pack/blank.png")
    }

    assert Pack.add_file(pack, nil, nil, file) == {:error, :einval}
  end

  test "returns pack when zip file is empty", %{pack: pack} do
    file = %Plug.Upload{
      content_type: "application/zip",
      filename: "emojis.zip",
      path: Path.absname("test/fixtures/empty.zip")
    }

    {:ok, updated_pack} = Pack.add_file(pack, nil, nil, file)
    assert updated_pack == pack
  end

  test "add emoji file", %{pack: pack} do
    file = %Plug.Upload{
      filename: "blank.png",
      path: "#{@emoji_path}/test_pack/blank.png"
    }

    {:ok, updated_pack} = Pack.add_file(pack, "test_blank", "test_blank.png", file)

    assert updated_pack.files == %{
             "test_blank" => "test_blank.png"
           }

    assert updated_pack.files_count == 1
  end
end
