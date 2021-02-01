package com.topjohnwu.magisk.di

import android.content.Context
import android.os.Build
import com.squareup.moshi.Moshi
import com.topjohnwu.magisk.BuildConfig
import com.topjohnwu.magisk.core.Config
import com.topjohnwu.magisk.core.Const
import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.data.network.GithubApiServices
import com.topjohnwu.magisk.data.network.GithubPageServices
import com.topjohnwu.magisk.data.network.JSDelivrServices
import com.topjohnwu.magisk.data.network.RawServices
import com.topjohnwu.magisk.ktx.precomputedText
import com.topjohnwu.magisk.net.Networking
import com.topjohnwu.magisk.net.NoSSLv3SocketFactory
import com.topjohnwu.magisk.utils.MarkwonImagePlugin
import io.noties.markwon.Markwon
import io.noties.markwon.html.HtmlPlugin
import okhttp3.Dns
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.dnsoverhttps.DnsOverHttps
import okhttp3.logging.HttpLoggingInterceptor
import org.koin.dsl.module
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.converter.scalars.ScalarsConverterFactory
import java.net.InetAddress
import java.net.UnknownHostException

val networkingModule = module {
    single { createOkHttpClient(get()) }
    single { createRetrofit(get()) }
    single { createApiService<RawServices>(get(), Const.Url.GITHUB_RAW_URL) }
    single { createApiService<GithubApiServices>(get(), Const.Url.GITHUB_API_URL) }
    single { createApiService<GithubPageServices>(get(), Const.Url.GITHUB_PAGE_URL) }
    single { createApiService<JSDelivrServices>(get(), Const.Url.JS_DELIVR_URL) }
    single { createMarkwon(get(), get()) }
}

private class DnsResolver(client: OkHttpClient) : Dns {

    private val doh by lazy {
        DnsOverHttps.Builder().client(client)
            .url(HttpUrl.get("https://cloudflare-dns.com/dns-query"))
            .bootstrapDnsHosts(listOf(
                InetAddress.getByName("162.159.36.1"),
                InetAddress.getByName("162.159.46.1"),
                InetAddress.getByName("1.1.1.1"),
                InetAddress.getByName("1.0.0.1"),
                InetAddress.getByName("162.159.132.53"),
                InetAddress.getByName("2606:4700:4700::1111"),
                InetAddress.getByName("2606:4700:4700::1001"),
                InetAddress.getByName("2606:4700:4700::0064"),
                InetAddress.getByName("2606:4700:4700::6400")
            ))
            .resolvePrivateAddresses(true)  /* To make PublicSuffixDatabase never used */
            .build()
    }

    override fun lookup(hostname: String): List<InetAddress> {
        if (Config.doh) {
            try {
                return doh.lookup(hostname)
            } catch (e: UnknownHostException) {}
        }
        return Dns.SYSTEM.lookup(hostname)
    }
}

@Suppress("DEPRECATION")
fun createOkHttpClient(context: Context): OkHttpClient {
    val builder = OkHttpClient.Builder()

    if (BuildConfig.DEBUG) {
        builder.addInterceptor(HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BASIC
        })
    }

    if (!Networking.init(context)) {
        Info.hasGMS = false
        if (Build.VERSION.SDK_INT < 21)
            builder.sslSocketFactory(NoSSLv3SocketFactory())
    }
    builder.dns(DnsResolver(builder.build()))

    return builder.build()
}

fun createMoshiConverterFactory(): MoshiConverterFactory {
    val moshi = Moshi.Builder().build()
    return MoshiConverterFactory.create(moshi)
}

fun createRetrofit(okHttpClient: OkHttpClient): Retrofit.Builder {
    return Retrofit.Builder()
        .addConverterFactory(ScalarsConverterFactory.create())
        .addConverterFactory(createMoshiConverterFactory())
        .client(okHttpClient)
}

inline fun <reified T> createApiService(retrofitBuilder: Retrofit.Builder, baseUrl: String): T {
    return retrofitBuilder
        .baseUrl(baseUrl)
        .build()
        .create(T::class.java)
}

fun createMarkwon(context: Context, okHttpClient: OkHttpClient): Markwon {
    return Markwon.builder(context)
        .textSetter { textView, spanned, _, onComplete ->
            textView.tag = onComplete
            textView.precomputedText = spanned
        }
        .usePlugin(HtmlPlugin.create())
        .usePlugin(MarkwonImagePlugin(okHttpClient))
        .build()
}
