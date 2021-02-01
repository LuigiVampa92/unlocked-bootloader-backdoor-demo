package com.topjohnwu.magisk.core.model

import android.os.Parcelable
import com.squareup.moshi.JsonClass
import kotlinx.parcelize.Parcelize

@JsonClass(generateAdapter = true)
data class UpdateInfo(
    val app: ManagerJson = ManagerJson(),
    val uninstaller: UninstallerJson = UninstallerJson(),
    val magisk: MagiskJson = MagiskJson(),
    val stub: StubJson = StubJson()
)

@JsonClass(generateAdapter = true)
data class UninstallerJson(
    val link: String = ""
)

@JsonClass(generateAdapter = true)
data class MagiskJson(
    val version: String = "",
    val versionCode: Int = -1,
    val link: String = "",
    val note: String = "",
    val md5: String = ""
)

@Parcelize
@JsonClass(generateAdapter = true)
data class ManagerJson(
    val version: String = "",
    val versionCode: Int = -1,
    val link: String = "",
    val note: String = ""
) : Parcelable

@Parcelize
@JsonClass(generateAdapter = true)
data class StubJson(
    val versionCode: Int = -1,
    val link: String = ""
) : Parcelable

@JsonClass(generateAdapter = true)
data class ModuleJson(
    val id: String,
    val last_update: Long,
    val prop_url: String,
    val zip_url: String,
    val notes_url: String
)

@JsonClass(generateAdapter = true)
data class RepoJson(
    val name: String,
    val last_update: Long,
    val modules: List<ModuleJson>
)

@JsonClass(generateAdapter = true)
data class CommitInfo(
    val sha: String
)

@JsonClass(generateAdapter = true)
data class BranchInfo(
    val commit: CommitInfo
)
