# 01: Cascading Metadata Storage & Bulk Update

**What to build:**
Implement `LibraryStorage.updateSegmentMetadata({required String dirPath, required String rootPath, Map<String, dynamic>? metadata})` to write updated `.metadata.json` on disk and perform a bulk prefix `UPDATE` across matching SQLite records.

**Blocked by:** None.

**Status:** ready-for-agent

- [ ] Write/update parent `.metadata.json` file on disk for the specified path segment
- [ ] Bulk update all SQLite entries matching `path LIKE '$dirPath/%'`
- [ ] Display confirmation dialog when affected count > 1
- [ ] Service unit tests verifying filesystem and database updates
