package com.topjohnwu.magisk.events

import android.os.Build
import android.os.PowerManager
import android.view.ContextThemeWrapper
import android.view.MenuItem
import android.widget.PopupMenu
import androidx.core.content.getSystemService
import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.core.base.BaseActivity
import com.topjohnwu.superuser.Shell
import com.topjohnwu.magisk.ktx.reboot as systemReboot

object RebootEvent {

    private fun reboot(item: MenuItem): Boolean {
        when (item.itemId) {
            R.id.action_reboot_normal -> systemReboot()
            R.id.action_reboot_userspace -> systemReboot("userspace")
            R.id.action_reboot_bootloader -> systemReboot("bootloader")
            R.id.action_reboot_download -> systemReboot("download")
            R.id.action_reboot_edl -> systemReboot("edl")
            R.id.action_reboot_recovery -> Shell.su("/system/bin/reboot recovery").submit()
            else -> Unit
        }
        return true
    }

    fun inflateMenu(activity: BaseActivity): PopupMenu {
        val themeWrapper = ContextThemeWrapper(activity, R.style.Foundation_PopupMenu)
        val menu = PopupMenu(themeWrapper, activity.findViewById(R.id.action_reboot))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            activity.getSystemService<PowerManager>()?.isRebootingUserspaceSupported == true)
            menu.menu.getItem(R.id.action_reboot_userspace).isVisible = true
        activity.menuInflater.inflate(R.menu.menu_reboot, menu.menu)
        menu.setOnMenuItemClickListener(::reboot)
        return menu
    }

}
