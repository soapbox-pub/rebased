# Managing emoji packs

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

## Lists emoji packs and metadata specified in the manifest

```sh tab="OTP"
./bin/pleroma_ctl emoji ls-packs [<options>]
```

```sh tab="From Source"
mix pleroma.emoji ls-packs [<options>]
```


### Options
- `-m, --manifest PATH/URL` - path to a custom manifest, it can either be an URL starting with `http`, in that case the manifest will be fetched from that address, or a local path

## Fetch, verify and install the specified packs from the manifest into `STATIC-DIR/emoji/PACK-NAME`

```sh tab="OTP"
./bin/pleroma_ctl emoji get-packs [<options>] <packs>
```

```sh tab="From Source"
mix pleroma.emoji get-packs [<options>] <packs>
```

### Options
- `-m, --manifest PATH/URL` - same as [`ls-packs`](#ls-packs)

## Create a new manifest entry and a file list from the specified remote pack file

```sh tab="OTP"
./bin/pleroma_ctl emoji gen-pack PACK-URL
```

```sh tab="From Source"
mix pleroma.emoji gen-pack PACK-URL
```

Currently, only .zip archives are recognized as remote pack files and packs are therefore assumed to be zip archives. This command is intended to run interactively and will first ask you some basic questions about the pack, then download the remote file and generate an SHA256 checksum for it, then generate an emoji file list for you. 

  The manifest entry will either be written to a newly created `index.json` file or appended to the existing one, *replacing* the old pack with the same name if it was in the file previously.

  The file list will be written to the file specified previously, *replacing* that file. You _should_ check that the file list doesn't contain anything you don't need in the pack, that is, anything that is not an emoji (the whole pack is downloaded, but only emoji files are extracted).
