# 调研与建议计划：主页 / Bilibili 页 / 智能搜索页的缓存策略

## Overview
你希望把“收藏夹页”已存在的显式页面数据缓存体系（`UnifiedCacheManager` 的 L1 内存 Map + L2 Hive + TTL；以及 `PageCacheService` 的页面级封装）扩展到 **主页、Bilibili 音乐库、智能搜索** 三个页面。
本任务目标是：
1) 用 `augment-context-engine-mcp` 在代码库中定位这三页的实现与数据拉取链路，并判断现有缓存/持久化痕迹；
2) 基于检索结果评估是否应复用现有缓存体系或采用替代方案；
3) 给出可落地的缓存 key/TTL/失效触发点设计建议（不直接改代码）。

> 说明：上次尝试调用 `augment-context-engine-mcp` 工具在当前环境报“Invalid tool name format”。本计划会 **优先再次尝试** 使用该工具；若再次失败，将请求你确认后改用 ACE 搜索工具作为替代以完成同等结论。

## Scope Analysis
- 代码改动：无（本任务为调研 + 设计建议）
- 需要定位的页面：
  - 主页（Home）
  - Bilibili 音乐库页（你指的 Bilibili Tab/页面，需确认具体入口）
  - 智能搜索页（Global/Smart Search）
- 需要覆盖的缓存类型（全面判断口径）：
  - 显式页面数据缓存：`UnifiedCacheManager`/`PageCacheService` 或类似
  - 复用/内存级缓存：单例 map、provider/state、memoization
  - 本地持久化：Drift/SQLite、Hive、文件缓存
  - 图片/媒体缓存：CachedNetworkImage、封面/音频缓存（需区分层级）
  - HTTP 层缓存/ETag/Cache-Control（若存在请求封装）
- 预计复杂度：中等（跨路由/页面/服务层追踪，且需要提出合理 key 设计）

## Execution Phases

### Phase 1：用 augment 定位页面入口与数据链路
**Objective**：分别找到三页对应的路由/菜单入口、页面组件文件、数据拉取入口（service/repo/API），并标注调用链。
**Delegated to**：Explore Agent（优先）
**Actions**：
- [ ] 用 `augment-context-engine-mcp` 定位：
  - 主页入口与主要数据来源
  - Bilibili 页入口与主要数据来源
  - 智能搜索页入口与主要数据来源
- [ ] 对每页输出：文件路径 + 关键类/方法名 + 触发时机（initState/onPageShow/refresh 等）
- [ ] 初步标注“是否已有缓存/持久化”线索（例如读写 `PageCacheService`、读 DB、单例 map、Hive 等）
**Acceptance Criteria**：
- 三个页面每个至少找到 1 个明确入口文件（路由/菜单 builder 指向的 Widget）。
- 每个页面至少找到 1 条“页面 -> 数据拉取入口 -> service/repo/API”链路。
- 产出可复核证据清单（路径 + 关键符号）。
- 诊断/构建验证：
  - IDE 诊断：若 IDE 插件不可用，则改用 `dart analyze` 对相关文件做最小集合检查（MANDATORY）。

### Phase 2：缓存现状盘点 + 复用可行性评估
**Objective**：基于 Phase 1 的链路，判断三页目前的缓存/持久化现状，并评估是否应复用 `UnifiedCacheManager`/`PageCacheService`。
**Delegated to**：General Purpose Agent（优先）
**Actions**：
- [ ] 对每页列出：
  - 当前是否已使用 `PageCacheService` / `UnifiedCacheManager`
  - 是否依赖 DB 作为“缓存/离线数据源”
  - 是否存在请求去重、内存 map、或其它缓存
- [ ] 评估复用边界：
  - 是按“页面”缓存还是按“接口/查询参数”缓存更合适
  - key 维度是否需要包含登录态、用户 id、搜索词、分页参数等
  - TTL 是否应分层（短 TTL + 后台刷新 vs 长 TTL + 手动刷新）
**Acceptance Criteria**：
- 对三页分别给出“是否适合复用现有页面缓存体系”的结论，并附证据。
- 明确指出如果复用，需要扩展/新增 `PageCacheService` 的哪些方法或命名空间。
- 诊断/构建验证：对 Phase 1 相关文件继续做最小集合 `dart analyze`（MANDATORY）。

### Phase 3：输出建议（key/TTL/行为/失效触发点 或 替代方案）
**Objective**：把建议落到可直接实现的规格（key 设计、TTL、命中行为、刷新/失效点），或给出更适合的替代方案与改动点。
**Delegated to**：Self（汇总输出）
**Actions**：
- [ ] 若建议复用：为每页给出
  - cache namespace
  - key 结构（含必要参数）
  - TTL
  - 命中行为（是否立即渲染缓存、是否后台刷新只更新缓存/是否更新 UI）
  - 失效触发点（下拉刷新、登录变化、搜索词变化、退出账号、清理缓存入口等）
- [ ] 若建议替代：明确
  - 替代方案是什么（例如：以 repository 为中心的 query-cache，或更细粒度的 API cache 层）
  - 会改动哪些文件/模块
  - 风险点与防护（key 冲突、污染、内存/磁盘增长、数据一致性）
**Acceptance Criteria**：
- 你能根据输出直接开工：每页都有可实现的 key/TTL/触发点规格或明确替代方案。

## Verification Strategy
- [ ] 每个 Phase 后执行最小集合 `dart analyze`（因为 IDE 诊断工具当前可能不可用）。
- [ ] 所有结论必须可由“打开文件定位关键代码”复核。

## Potential Risks
- `augment-context-engine-mcp` 工具在当前环境可能不可用/命名不匹配；需要你确认后改用 ACE 搜索作为降级。
- “Bilibili 音乐库”可能存在多个入口（Tab 页/子页面/详情页），需要先确认你指的具体页面（例如底部导航的 Bilibili Tab）。
- 缓存 key 设计如果缺少登录态/用户维度，可能造成数据串号（污染）。

## Rollback Plan
不修改代码，无需回滚。
