package com.topjohnwu.magisk.view

import android.annotation.TargetApi
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.core.content.getSystemService
import androidx.core.graphics.drawable.IconCompat
import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.core.Const
import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.ktx.getBitmap
import com.topjohnwu.magisk.utils.Utils

object Shortcuts {

    fun setupDynamic(context: Context) {
        if (Build.VERSION.SDK_INT >= 25) {
            val manager = context.getSystemService<ShortcutManager>() ?: return
            manager.dynamicShortcuts = getShortCuts(context)
        }
    }

    @TargetApi(26)
    fun addHomeIcon(context: Context) {
        val manager = context.getSystemService<ShortcutManager>() ?: return
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
        val info = ShortcutInfo.Builder(context, Const.Nav.HOME)
            .setShortLabel(context.getString(R.string.app_name))
            .setIntent(intent)
            .setIcon(context.getIcon(R.drawable.ic_launcher))
            .build()
        manager.requestPinShortcut(info, null)
    }

    private fun Context.getIconCompat(id: Int): IconCompat {
        return if (Build.VERSION.SDK_INT >= 26)
            IconCompat.createWithAdaptiveBitmap(getBitmap(id))
        else
            IconCompat.createWithBitmap(getBitmap(id))
    }

    @RequiresApi(api = 23)
    private fun Context.getIcon(id: Int) = getIconCompat(id).toIcon(this)

    @RequiresApi(api = 25)
    private fun getShortCuts(context: Context): List<ShortcutInfo> {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return emptyList()

        val shortCuts = mutableListOf<ShortcutInfo>()

        if (Utils.showSuperUser()) {
            shortCuts.add(
                ShortcutInfo.Builder(context, Const.Nav.SUPERUSER)
                    .setShortLabel(context.getString(R.string.superuser))
                    .setIntent(
                        Intent(intent).putExtra(Const.Key.OPEN_SECTION, Const.Nav.SUPERUSER)
                    )
                    .setIcon(context.getIcon(R.drawable.sc_superuser))
                    .setRank(0)
                    .build()
            )
        }
        if (Info.env.magiskHide) {
            shortCuts.add(
                ShortcutInfo.Builder(context, Const.Nav.HIDE)
                    .setShortLabel(context.getString(R.string.magiskhide))
                    .setIntent(
                        Intent(intent).putExtra(Const.Key.OPEN_SECTION, Const.Nav.HIDE)
                    )
                    .setIcon(context.getIcon(R.drawable.sc_magiskhide))
                    .setRank(1)
                    .build()
            )
        }
        if (Info.env.isActive) {
            shortCuts.add(
                ShortcutInfo.Builder(context, Const.Nav.MODULES)
                    .setShortLabel(context.getString(R.string.modules))
                    .setIntent(
                        Intent(intent).putExtra(Const.Key.OPEN_SECTION, Const.Nav.MODULES)
                    )
                    .setIcon(context.getIcon(R.drawable.sc_extension))
                    .setRank(2)
                    .build()
            )
        }
        return shortCuts
    }
}
