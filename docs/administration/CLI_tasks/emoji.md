# Managing emoji packs

Every command should be ran with a prefix, in case of OTP releases it is `./bin/pleroma_ctl emoji` and in case of source installs it's `mix pleroma.emoji`.

## Lists emoji packs and metadata specified in the manifest

```sh
$PREFIX ls-packs [<options>]
```

### Options
- `-m, --manifest PATH/URL` - path to a custom manifest, it can either be an URL starting with `http`, in that case the manifest will be fetched from that address, or a local path

## Fetch, verify and install the specified packs from the manifest into `STATIC-DIR/emoji/PACK-NAME`
```sh
$PREFIX get-packs [<options>] <packs>
```

### Options
- `-m, --manifest PATH/URL` - same as [`ls-packs`](#ls-packs)

## Create a new manifest entry and a file list from the specified remote pack file
```sh
$PREFIX gen-pack PACK-URL
```
Currently, only .zip archives are recognized as remote pack files and packs are therefore assumed to be zip archives. This command is intended to run interactively and will first ask you some basic questions about the pack, then download the remote file and generate an SHA256 checksum for it, then generate an emoji file list for you. 

  The manifest entry will either be written to a newly created `index.json` file or appended to the existing one, *replacing* the old pack with the same name if it was in the file previously.

  The file list will be written to the file specified previously, *replacing* that file. You _should_ check that the file list doesn't contain anything you don't need in the pack, that is, anything that is not an emoji (the whole pack is downloaded, but only emoji files are extracted).
