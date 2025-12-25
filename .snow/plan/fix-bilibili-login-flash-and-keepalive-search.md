# Implementation Plan: 修复 Bilibili 音乐库“登录页闪现” + 智能搜索入口页仅做页面保活

## Overview

你提出两点需求：

1. 进入“Bilibili 音乐库”(底部导航 Bilibili Tab，实际页面为 `BilibiliFavoritesPage`) 时，不要出现“先显示登录页 UI 再跳回收藏夹”的闪屏；如果鉴权未完成，应显示稳定的占位/加载态。
2. 智能搜索：仅做导航栏入口页的“页面实例/状态保活”（尽量不重建、保留滚动位置），不把入口页内容写入 `UnifiedCacheManager` / `PageCacheService` 等跨页面持久化缓存；除非必须，不改动搜索结果页现有缓存。

## Scope Analysis

- Files to be modified:
  - `lib/views/bilibili/favorites_page.dart`：增加“鉴权检查中”稳定占位，避免未确认登录态时渲染“未登录视图”。
  - `lib/router/router.dart`：让 `GlobalSearchPage` 正确绑定 `pageKey`（builder 传入 key），为入口页保活/回到页面时的生命周期回调铺路。
  - （可选）`lib/views/bilibili/global_search_page.dart`：仅做页面级状态保活增强（例如 `PageStorageKey` 保滚动），不引入持久化数据缓存。
- New files to be created: 无
- Dependencies/related modules:
  - `lib/services/bilibili/cookie_manager.dart`：`CookieManager.isLoggedIn()` 是异步 SharedPreferences 读取。
  - `lib/views/bilibili/login_page.dart`：仅在用户点击登录按钮时 push；不应自动弹出。
  - `lib/views/home_page_desktop.dart`：主界面用 `IndexedStack(children: menuManager.pages)`，理论上可以保留页面 State。
- Estimated complexity: medium（涉及页面初始化时序 + UI 状态机；改动需小心避免破坏现有加载/刷新逻辑）

## Problem 定位（当前最可能原因）

- `BilibiliFavoritesPage` 初始 `_isLoggedIn=false`（`lib/views/bilibili/favorites_page.dart:56`），`initState` 里异步调用 `_checkLoginAndLoadData()`（`lib/views/bilibili/favorites_page.dart:80`）。
- `_checkLoginAndLoadData()` 通过 `CookieManager.isLoggedIn()` 异步判定登录（`lib/views/bilibili/favorites_page.dart:187-199`）。在异步返回前，`build()` 会走 `_buildContentSlivers()`，因为 `_isLoggedIn` 仍为 false，会渲染 `_buildNotLoggedInView()`（`lib/views/bilibili/favorites_page.dart:1138-1144`），其 UI 文案与按钮非常像“登录页”。
- 当异步判定返回 true，setState 将 `_isLoggedIn=true`，随后加载收藏夹并切换到正常内容，导致你观察到“登录页闪现”。

## Execution Phases

### Phase 1: 修复 Bilibili 音乐库进入时的“登录 UI 闪现”

**Objective**: 在登录态未确认（异步检查中）时，不渲染 `_buildNotLoggedInView()`，改为稳定 Loading 占位；仅在确认未登录后才展示未登录视图。
**Delegated to**: General Purpose Agent（优先）
**Files**: `lib/views/bilibili/favorites_page.dart`
**Actions**:

- [x] 引入 `bool _isCheckingLogin`：初始为 true。
- [x] `_checkLoginAndLoadData()` 在请求前/后更新状态：进入时设为 checking；获取结果后同步写入 `_isLoggedIn` + `_isCheckingLogin=false`。
- [x] `_buildContentSlivers()` 优先判断 `_isCheckingLogin`：返回稳定 Loading 占位，避免未登录视图在异步检查期间被 build。
- [x] 退出登录（`_handleLogout()`）将 `_isCheckingLogin=false`，保证退出后直接展示未登录视图。
      **Acceptance Criteria**:
- 从任意页面切到 Bilibili Tab：
  - 不出现“请先登录 Bilibili 账号 / 登录按钮”的闪现。
  - 若需要等待 SharedPreferences/鉴权：只出现稳定 Loading 占位。
  - 若最终判定已登录：直接进入收藏夹 UI。
  - 若最终判定未登录：展示未登录视图（且仅在判定后）。
- Build/compile verification:
  - `dart analyze --no-fatal-warnings lib/views/bilibili/favorites_page.dart`（无 error；仅存在既有 warnings/infos，且本次不会引入新 error）。

### Phase 2: 智能搜索入口页仅做页面保活（不引入入口数据持久化缓存）

> Phase 1 已完成并通过最小诊断验证，等待你确认后再开始 Phase 2。

**Objective**: 让导航栏里的 `GlobalSearchPage` 更可靠地保持页面实例/滚动状态；不对入口页内容引入 `UnifiedCacheManager`/`PageCacheService` 持久化缓存；不改动搜索结果页缓存逻辑。
**Delegated to**: General Purpose Agent（优先）
**Files**:

- 必改：`lib/router/router.dart`
- 可选：`lib/views/bilibili/global_search_page.dart`
  **Actions**:
- [x] 在 `lib/router/router.dart:100` 将 `GlobalSearchPage` builder 改为传入 `key`：`builder: (key) => GlobalSearchPage(key: key)`（去掉 `const`），使其能被 `MenuManager` 的 `pageKey` 正确引用并触发 `onPageShow`。
- [x] 为 `GlobalSearchPage` 的 `CustomScrollView` 增加 `PageStorageKey`（`global_search_scroll`），在发生重建时尽量保留滚动位置；不改动 `_loadCategories()` 的数据策略，不写入 `PageCacheService`。
- [x] 不改动 `lib/views/bilibili/global_search_result_page.dart` 中现有搜索结果缓存逻辑。
      **Acceptance Criteria**:
- 在底部导航切换离开/返回“智能搜索”入口页：
  - 页面不被重新 init（理想情况下）或至少滚动位置可恢复。
  - 入口页不新增任何 `UnifiedCacheManager` / `PageCacheService` 写入。
- Build/compile verification:
  - `dart analyze --no-fatal-warnings lib/router/router.dart lib/views/bilibili/global_search_page.dart`（exitCode=0，无 error；仅存在既有 warnings/infos）。

### Phase 3: 验证与回归检查

**Objective**: 确认改动不引入新的诊断错误，并回归关键交互。
**Delegated to**: Self（执行验证命令与人工复核）
**Actions**:

- [ ] 运行 `dart analyze`（最小集合：上述修改文件）。
- [ ] 快速人工复核：Bilibili Tab 登录态切换、退出登录后 UI 状态、智能搜索 Tab 切换滚动位置。
      **Acceptance Criteria**:
- `dart analyze` 对修改文件无 error。
- 目标体验达成（见各 Phase 的验收表现）。

## Verification Strategy

- [ ] 每个 Phase 结束后：`dart analyze`（至少对涉及文件）。
- [ ] 手动验收：
  - 切到 Bilibili Tab 不再闪现“未登录/登录按钮”视图。
  - 切到智能搜索入口页离开再返回：页面状态尽量保持（滚动/已加载内容）。

## Potential Risks

- 将鉴权状态拆成三态（checking/loggedIn/loggedOut）时，需避免与现有 `_isLoading`（加载收藏夹）逻辑互相覆盖。
- `router.dart` builder 去掉 `const` 并传 key 可能影响重建频率，但一般是正向修复（绑定 pageKey，利于生命周期回调）。

## Rollback Plan

- 所有改动都局限在 UI 层：可通过 `git checkout -- <file>` 回滚到改动前状态。
