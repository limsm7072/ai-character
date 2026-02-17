package com.aicharacter.ai_character

import android.os.Bundle
import android.app.Activity

/**
 * Dummy activity required by Health Connect to show this app
 * in its list of connected apps. When the user opens
 * "App permissions" in Health Connect, this activity is launched.
 * We simply finish immediately — the actual permission flow
 * is handled by the health Flutter plugin.
 */
class HealthPermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        finish()
    }
}
