package com.mottomusic.player

import io.flutter.app.FlutterApplication

class MottoMusicApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        LockScreenController.initialize(this)
    }
}
