# Changelog

All notable changes to this project will be documented in this file.
This file is only for changes to Soapbox.
For changes to Pleroma, see `CHANGELOG.md`

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.1.0] - unreleased

Based on Pleroma 2.3.0-stable.

### Added
- Twitter-like block behavior, configured under "ActivityPub > Blockers visible" in AdminFE.
- The Soapbox version in `/api/v1/instance`

### Changed
- Twitter-like block behavior is now the default.

### Fixed
- Domain blocks: reposts from a blocked domain are now correctly blocked.
- Fixed some (not all) Markdown issues, such as broken trailing slash in links.
