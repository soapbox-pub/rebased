# Changelog

All notable changes to this project will be documented in this file.
This file is only for changes to Soapbox.
For changes to Pleroma, see `CHANGELOG.md`

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## unreleased

Based on Pleroma 2.3.0-stable.

### Added
- Retain uploaded image aspect ratios.

### Fixed
- Rich media not working for certain links.

## [1.0.0] - 2021-05-11

Based on Pleroma 2.3.0-stable.

### Added
- Rich media embeds for sites like YouTube, etc. ([!13](https://gitlab.com/soapbox-pub/soapbox/-/merge_requests/13))
- Twitter-like block behavior, configured under "ActivityPub > Blockers visible" in AdminFE. ([!9](https://gitlab.com/soapbox-pub/soapbox/-/merge_requests/9))
- The Soapbox version in `/api/v1/instance` ([!6](https://gitlab.com/soapbox-pub/soapbox/-/merge_requests/6))

### Changed
- Soapbox FE is set as the default frontend. ([!16](https://gitlab.com/soapbox-pub/soapbox/-/merge_requests/16))
- Twitter-like block behavior is now the default. ([!9](https://gitlab.com/soapbox-pub/soapbox/-/merge_requests/9))

### Fixed
- Domain blocks: reposts from a blocked domain are now correctly blocked. ([!11](https://gitlab.com/soapbox-pub/soapbox/-/merge_requests/11))
- Fixed some (not all) Markdown issues, such as broken trailing slash in links. ([!10](https://gitlab.com/soapbox-pub/soapbox/-/merge_requests/10))
- Don't crash so hard when email settings are invalid. ([!12](https://gitlab.com/soapbox-pub/soapbox/-/merge_requests/12))
- Return OpenGraph metadata on Soapbox FE routes. ([!14](https://gitlab.com/soapbox-pub/soapbox/-/merge_requests/14))
