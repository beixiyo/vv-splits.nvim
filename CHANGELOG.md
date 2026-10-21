# Changelog

## Unreleased

### Breaking

- 删除 `VVSplitsSetupOpts`，`setup` 入参统一为 `VVSplitsOpts`
- setup() 不再返回配置，需要时用 get_config()

### Changed

- 合并语义保持不变，仍为浅层 `tbl_extend`
