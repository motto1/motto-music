import 'config_manager.dart';
import 'modules/theme_config_module.dart';
import 'modules/user_settings_config_module.dart';
import 'modules/player_prefs_config_module.dart';
import 'modules/bilibili_library_module.dart';
import 'modules/bilibili_auth_module.dart';
import 'modules/lyrics_config_module.dart';
import '../database/database.dart';
import '../services/bilibili/cookie_manager.dart';

/// 创建默认配置管理器（内置模块注册）。
ConfigManager createDefaultConfigManager() {
  final db = MusicDatabase.database;
  return ConfigManager([
    ThemeConfigModule(),
    UserSettingsConfigModule(db),
    PlayerPrefsConfigModule(),
    BilibiliLibraryModule(db),
    BilibiliAuthModule(CookieManager()),
    LyricsConfigModule(db),
  ]);
}

