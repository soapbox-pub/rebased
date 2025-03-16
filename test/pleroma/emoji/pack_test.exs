# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emoji.PackTest do
  use Pleroma.DataCase
  alias Pleroma.Emoji
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

    test "skips existing emojis when adding from zip file", %{pack: pack} do
      # First, let's create a test pack with a "bear" emoji
      test_pack_path = Path.join(@emoji_path, "test_bear_pack")
      File.mkdir_p(test_pack_path)

      # Create a pack.json file
      File.write!(Path.join(test_pack_path, "pack.json"), """
      {
      "files": { "bear": "bear.png" },
      "pack": {
      "description": "Bear Pack", "homepage": "https://pleroma.social",
      "license": "Test license", "share-files": true
      }}
      """)

      # Copy a test image to use as the bear emoji
      File.cp!(
        Path.absname("test/instance_static/emoji/test_pack/blank.png"),
        Path.join(test_pack_path, "bear.png")
      )

      # Load the pack to register the "bear" emoji in the global registry
      {:ok, _bear_pack} = Pleroma.Emoji.Pack.load_pack("test_bear_pack")

      # Reload emoji to make sure the bear emoji is in the global registry
      Emoji.reload()

      # Verify that the bear emoji exists in the global registry
      assert Emoji.exist?("bear")

      # Now try to add a zip file that contains an emoji with the same shortcode
      file = %Plug.Upload{
        content_type: "application/zip",
        filename: "emojis.zip",
        path: Path.absname("test/fixtures/emojis.zip")
      }

      {:ok, updated_pack} = Pack.add_file(pack, nil, nil, file)

      # Verify that the "bear" emoji was skipped
      refute Map.has_key?(updated_pack.files, "bear")

      # Other emojis should be added
      assert Map.has_key?(updated_pack.files, "a_trusted_friend-128")
      assert Map.has_key?(updated_pack.files, "auroraborealis")
      assert Map.has_key?(updated_pack.files, "baby_in_a_box")
      assert Map.has_key?(updated_pack.files, "bear-128")

      # Total count should be 4 (all emojis except "bear")
      assert updated_pack.files_count == 4

      # Clean up the test pack
      on_exit(fn ->
        File.rm_rf!(test_pack_path)
      end)
    end
  end

  test "returns error when zip file is bad", %{pack: pack} do
    file = %Plug.Upload{
      content_type: "application/zip",
      filename: "emojis.zip",
      path: Path.absname("test/instance_static/emoji/test_pack/blank.png")
    }

    assert {:error, _} = Pack.add_file(pack, nil, nil, file)
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

  test "load_pack/1 ignores path traversal in a forged pack name", %{pack: pack} do
    assert {:ok, ^pack} = Pack.load_pack("../../../../../dump_pack")
  end
end
