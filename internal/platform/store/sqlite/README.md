# SQLite 持久化适配器（预留）
目前 bootstrap 默认使用 `JSONStore`，支持原子替换与持久化，以便不引入外部 Go 依赖并在 Linux/Windows 直接验证。
规划采用 `database/sql` + 独立 SQLite driver（待选择并锁定依赖版本），通过 Store 接口替换 JSONStore，执行迁移、WAL、备份和冲突版本控制。
现阶段绝不能宣传已实现 SQLite。
