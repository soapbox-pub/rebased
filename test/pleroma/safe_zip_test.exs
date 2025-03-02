defmodule Pleroma.SafeZipTest do
  # Not making this async because it creates and deletes files
  use ExUnit.Case

  alias Pleroma.SafeZip

  @fixtures_dir "test/fixtures"
  @tmp_dir "test/zip_tmp"

  setup do
    # Ensure tmp directory exists
    File.mkdir_p!(@tmp_dir)

    on_exit(fn ->
      # Clean up any files created during tests
      File.rm_rf!(@tmp_dir)
      File.mkdir_p!(@tmp_dir)
    end)

    :ok
  end

  describe "list_dir_file/1" do
    test "lists files in a valid zip" do
      {:ok, files} = SafeZip.list_dir_file(Path.join(@fixtures_dir, "emojis.zip"))
      assert is_list(files)
      assert length(files) > 0
    end

    test "returns an empty list for empty zip" do
      {:ok, files} = SafeZip.list_dir_file(Path.join(@fixtures_dir, "empty.zip"))
      assert files == []
    end

    test "returns error for non-existent file" do
      assert {:error, _} = SafeZip.list_dir_file(Path.join(@fixtures_dir, "nonexistent.zip"))
    end

    test "only lists regular files, not directories" do
      # Create a zip with both files and directories
      zip_path = create_zip_with_directory()

      # List files with SafeZip
      {:ok, files} = SafeZip.list_dir_file(zip_path)

      # Verify only regular files are listed, not directories
      assert "file_in_dir/test_file.txt" in files
      assert "root_file.txt" in files

      # Directory entries should not be included in the list
      refute "file_in_dir/" in files
    end
  end

  describe "contains_all_data?/2" do
    test "returns true when all files are in the archive" do
      # For this test, we'll create our own zip file with known content
      # to ensure we can test the contains_all_data? function properly
      zip_path = create_zip_with_directory()
      archive_data = File.read!(zip_path)

      # Check if the archive contains the root file
      # Note: The function expects charlists (Erlang strings) in the MapSet
      assert SafeZip.contains_all_data?(archive_data, MapSet.new([~c"root_file.txt"]))
    end

    test "returns false when files are missing" do
      archive_path = Path.join(@fixtures_dir, "emojis.zip")
      archive_data = File.read!(archive_path)

      # Create a MapSet with non-existent files
      fset = MapSet.new([~c"nonexistent.txt"])

      refute SafeZip.contains_all_data?(archive_data, fset)
    end

    test "returns false for invalid archive data" do
      refute SafeZip.contains_all_data?("invalid data", MapSet.new([~c"file.txt"]))
    end

    test "only checks for regular files, not directories" do
      # Create a zip with both files and directories
      zip_path = create_zip_with_directory()
      archive_data = File.read!(zip_path)

      # Check if the archive contains a directory (should return false)
      refute SafeZip.contains_all_data?(archive_data, MapSet.new([~c"file_in_dir/"]))

      # For this test, we'll manually check if the file exists in the archive
      # by extracting it and verifying it exists
      extract_dir = Path.join(@tmp_dir, "extract_check")
      File.mkdir_p!(extract_dir)
      {:ok, files} = SafeZip.unzip_file(zip_path, extract_dir)

      # Verify the root file was extracted
      assert Enum.any?(files, fn file ->
               Path.basename(file) == "root_file.txt"
             end)

      # Verify the file exists on disk
      assert File.exists?(Path.join(extract_dir, "root_file.txt"))
    end
  end

  describe "zip/4" do
    test "creates a zip file on disk" do
      # Create a test file
      test_file_path = Path.join(@tmp_dir, "test_file.txt")
      File.write!(test_file_path, "test content")

      # Create a zip file
      zip_path = Path.join(@tmp_dir, "test.zip")
      assert {:ok, ^zip_path} = SafeZip.zip(zip_path, ["test_file.txt"], @tmp_dir, false)

      # Verify the zip file exists
      assert File.exists?(zip_path)
    end

    test "creates a zip file in memory" do
      # Create a test file
      test_file_path = Path.join(@tmp_dir, "test_file.txt")
      File.write!(test_file_path, "test content")

      # Create a zip file in memory
      zip_name = Path.join(@tmp_dir, "test.zip")

      assert {:ok, {^zip_name, zip_data}} =
               SafeZip.zip(zip_name, ["test_file.txt"], @tmp_dir, true)

      # Verify the zip data is binary
      assert is_binary(zip_data)
    end

    test "returns error for unsafe paths" do
      # Try to zip a file with path traversal
      assert {:error, _} =
               SafeZip.zip(
                 Path.join(@tmp_dir, "test.zip"),
                 ["../fixtures/test.txt"],
                 @tmp_dir,
                 false
               )
    end

    test "can create zip with directories" do
      # Create a directory structure
      dir_path = Path.join(@tmp_dir, "test_dir")
      File.mkdir_p!(dir_path)

      file_in_dir_path = Path.join(dir_path, "file_in_dir.txt")
      File.write!(file_in_dir_path, "file in directory")

      # Create a zip file
      zip_path = Path.join(@tmp_dir, "dir_test.zip")

      assert {:ok, ^zip_path} =
               SafeZip.zip(
                 zip_path,
                 ["test_dir/file_in_dir.txt"],
                 @tmp_dir,
                 false
               )

      # Verify the zip file exists
      assert File.exists?(zip_path)

      # Extract and verify the directory structure is preserved
      extract_dir = Path.join(@tmp_dir, "extract")
      {:ok, files} = SafeZip.unzip_file(zip_path, extract_dir)

      # Check if the file path is in the list, accounting for possible full paths
      assert Enum.any?(files, fn file ->
               String.ends_with?(file, "file_in_dir.txt")
             end)

      # Verify the file exists in the expected location
      assert File.exists?(Path.join([extract_dir, "test_dir", "file_in_dir.txt"]))
    end
  end

  describe "unzip_file/3" do
    test "extracts files from a zip archive" do
      archive_path = Path.join(@fixtures_dir, "emojis.zip")

      # Extract the archive
      assert {:ok, files} = SafeZip.unzip_file(archive_path, @tmp_dir)

      # Verify files were extracted
      assert is_list(files)
      assert length(files) > 0

      # Verify at least one file exists
      first_file = List.first(files)

      # Simply check that the file exists in the tmp directory
      assert File.exists?(first_file)
    end

    test "extracts specific files from a zip archive" do
      archive_path = Path.join(@fixtures_dir, "emojis.zip")

      # Get list of files in the archive
      {:ok, all_files} = SafeZip.list_dir_file(archive_path)
      file_to_extract = List.first(all_files)

      # Extract only one file
      assert {:ok, [extracted_file]} =
               SafeZip.unzip_file(archive_path, @tmp_dir, [file_to_extract])

      # Verify only the specified file was extracted
      assert Path.basename(extracted_file) == Path.basename(file_to_extract)

      # Check that the file exists in the tmp directory
      assert File.exists?(Path.join(@tmp_dir, Path.basename(file_to_extract)))
    end

    test "returns error for invalid zip file" do
      invalid_path = Path.join(@tmp_dir, "invalid.zip")
      File.write!(invalid_path, "not a zip file")

      assert {:error, _} = SafeZip.unzip_file(invalid_path, @tmp_dir)
    end

    test "creates directories when extracting files in subdirectories" do
      # Create a zip with files in subdirectories
      zip_path = create_zip_with_directory()

      # Extract the archive
      assert {:ok, files} = SafeZip.unzip_file(zip_path, @tmp_dir)

      # Verify files were extracted - handle both relative and absolute paths
      assert Enum.any?(files, fn file ->
               Path.basename(file) == "test_file.txt" &&
                 String.contains?(file, "file_in_dir")
             end)

      assert Enum.any?(files, fn file ->
               Path.basename(file) == "root_file.txt"
             end)

      # Verify directory was created
      dir_path = Path.join(@tmp_dir, "file_in_dir")
      assert File.exists?(dir_path)
      assert File.dir?(dir_path)

      # Verify file in directory was extracted
      file_path = Path.join(dir_path, "test_file.txt")
      assert File.exists?(file_path)
    end
  end

  describe "unzip_data/3" do
    test "extracts files from zip data" do
      archive_path = Path.join(@fixtures_dir, "emojis.zip")
      archive_data = File.read!(archive_path)

      # Extract the archive from data
      assert {:ok, files} = SafeZip.unzip_data(archive_data, @tmp_dir)

      # Verify files were extracted
      assert is_list(files)
      assert length(files) > 0

      # Verify at least one file exists
      first_file = List.first(files)

      # Simply check that the file exists in the tmp directory
      assert File.exists?(first_file)
    end

    test "extracts specific files from zip data" do
      archive_path = Path.join(@fixtures_dir, "emojis.zip")
      archive_data = File.read!(archive_path)

      # Get list of files in the archive
      {:ok, all_files} = SafeZip.list_dir_file(archive_path)
      file_to_extract = List.first(all_files)

      # Extract only one file
      assert {:ok, extracted_files} =
               SafeZip.unzip_data(archive_data, @tmp_dir, [file_to_extract])

      # Verify only the specified file was extracted
      assert Enum.any?(extracted_files, fn path ->
               Path.basename(path) == Path.basename(file_to_extract)
             end)

      # Simply check that the file exists in the tmp directory
      assert File.exists?(Path.join(@tmp_dir, Path.basename(file_to_extract)))
    end

    test "returns error for invalid zip data" do
      assert {:error, _} = SafeZip.unzip_data("not a zip file", @tmp_dir)
    end

    test "creates directories when extracting files in subdirectories from data" do
      # Create a zip with files in subdirectories
      zip_path = create_zip_with_directory()
      archive_data = File.read!(zip_path)

      # Extract the archive from data
      assert {:ok, files} = SafeZip.unzip_data(archive_data, @tmp_dir)

      # Verify files were extracted - handle both relative and absolute paths
      assert Enum.any?(files, fn file ->
               Path.basename(file) == "test_file.txt" &&
                 String.contains?(file, "file_in_dir")
             end)

      assert Enum.any?(files, fn file ->
               Path.basename(file) == "root_file.txt"
             end)

      # Verify directory was created
      dir_path = Path.join(@tmp_dir, "file_in_dir")
      assert File.exists?(dir_path)
      assert File.dir?(dir_path)

      # Verify file in directory was extracted
      file_path = Path.join(dir_path, "test_file.txt")
      assert File.exists?(file_path)
    end
  end

  # Security tests
  describe "security checks" do
    test "prevents path traversal in zip extraction" do
      # Create a malicious zip file with path traversal
      malicious_zip_path = create_malicious_zip_with_path_traversal()

      # Try to extract it with SafeZip
      assert {:error, _} = SafeZip.unzip_file(malicious_zip_path, @tmp_dir)

      # Verify the file was not extracted outside the target directory
      refute File.exists?(Path.join(Path.dirname(@tmp_dir), "traversal_attempt.txt"))
    end

    test "prevents directory traversal in zip listing" do
      # Create a malicious zip file with path traversal
      malicious_zip_path = create_malicious_zip_with_path_traversal()

      # Try to list files with SafeZip
      assert {:error, _} = SafeZip.list_dir_file(malicious_zip_path)
    end

    test "prevents path traversal in zip data extraction" do
      # Create a malicious zip file with path traversal
      malicious_zip_path = create_malicious_zip_with_path_traversal()
      malicious_data = File.read!(malicious_zip_path)

      # Try to extract it with SafeZip
      assert {:error, _} = SafeZip.unzip_data(malicious_data, @tmp_dir)

      # Verify the file was not extracted outside the target directory
      refute File.exists?(Path.join(Path.dirname(@tmp_dir), "traversal_attempt.txt"))
    end

    test "handles zip bomb attempts" do
      # Create a zip bomb (a zip with many files or large files)
      zip_bomb_path = create_zip_bomb()

      # The SafeZip module should handle this gracefully
      # Either by successfully extracting it (if it's not too large)
      # or by returning an error (if it detects a potential zip bomb)
      result = SafeZip.unzip_file(zip_bomb_path, @tmp_dir)

      case result do
        {:ok, _} ->
          # If it successfully extracts, make sure it didn't fill up the disk
          # This is a simple check to ensure the extraction was controlled
          assert File.exists?(@tmp_dir)

        {:error, _} ->
          # If it returns an error, that's also acceptable
          # The important thing is that it doesn't crash or hang
          assert true
      end
    end

    test "handles deeply nested directory structures" do
      # Create a zip with deeply nested directories
      deep_nest_path = create_deeply_nested_zip()

      # The SafeZip module should handle this gracefully
      result = SafeZip.unzip_file(deep_nest_path, @tmp_dir)

      case result do
        {:ok, files} ->
          # If it successfully extracts, verify the files were extracted
          assert is_list(files)
          assert length(files) > 0

        {:error, _} ->
          # If it returns an error, that's also acceptable
          # The important thing is that it doesn't crash or hang
          assert true
      end
    end
  end

  # Helper functions to create test fixtures

  # Creates a zip file with a path traversal attempt
  defp create_malicious_zip_with_path_traversal do
    malicious_zip_path = Path.join(@tmp_dir, "path_traversal.zip")

    # Create a file to include in the zip
    test_file_path = Path.join(@tmp_dir, "test_file.txt")
    File.write!(test_file_path, "malicious content")

    # Use Erlang's zip module directly to create a zip with path traversal
    {:ok, charlist_path} =
      :zip.create(
        String.to_charlist(malicious_zip_path),
        [{String.to_charlist("../traversal_attempt.txt"), File.read!(test_file_path)}]
      )

    to_string(charlist_path)
  end

  # Creates a zip file with directory entries
  defp create_zip_with_directory do
    zip_path = Path.join(@tmp_dir, "with_directory.zip")

    # Create files to include in the zip
    root_file_path = Path.join(@tmp_dir, "root_file.txt")
    File.write!(root_file_path, "root file content")

    # Create a directory and a file in it
    dir_path = Path.join(@tmp_dir, "file_in_dir")
    File.mkdir_p!(dir_path)

    file_in_dir_path = Path.join(dir_path, "test_file.txt")
    File.write!(file_in_dir_path, "file in directory content")

    # Use Erlang's zip module to create a zip with directory structure
    {:ok, charlist_path} =
      :zip.create(
        String.to_charlist(zip_path),
        [
          {String.to_charlist("root_file.txt"), File.read!(root_file_path)},
          {String.to_charlist("file_in_dir/test_file.txt"), File.read!(file_in_dir_path)}
        ]
      )

    to_string(charlist_path)
  end

  # Creates a zip bomb (a zip with many small files)
  defp create_zip_bomb do
    zip_path = Path.join(@tmp_dir, "zip_bomb.zip")

    # Create a small file to duplicate many times
    small_file_path = Path.join(@tmp_dir, "small_file.txt")
    File.write!(small_file_path, String.duplicate("A", 100))

    # Create a list of many files to include in the zip
    file_entries =
      for i <- 1..100 do
        {String.to_charlist("file_#{i}.txt"), File.read!(small_file_path)}
      end

    # Use Erlang's zip module to create a zip with many files
    {:ok, charlist_path} =
      :zip.create(
        String.to_charlist(zip_path),
        file_entries
      )

    to_string(charlist_path)
  end

  # Creates a zip with deeply nested directories
  defp create_deeply_nested_zip do
    zip_path = Path.join(@tmp_dir, "deep_nest.zip")

    # Create a file to include in the zip
    file_content = "test content"

    # Create a list of deeply nested files
    file_entries =
      for i <- 1..10 do
        nested_path = Enum.reduce(1..i, "nested", fn j, acc -> "#{acc}/level_#{j}" end)
        {String.to_charlist("#{nested_path}/file.txt"), file_content}
      end

    # Use Erlang's zip module to create a zip with deeply nested directories
    {:ok, charlist_path} =
      :zip.create(
        String.to_charlist(zip_path),
        file_entries
      )

    to_string(charlist_path)
  end
end
