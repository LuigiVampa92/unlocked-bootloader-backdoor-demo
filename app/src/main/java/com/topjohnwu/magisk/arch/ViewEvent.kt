package com.topjohnwu.magisk.arch

import android.content.Context
import kotlinx.coroutines.CoroutineScope

/**
 * Class for passing events from ViewModels to Activities/Fragments
 * (see https://medium.com/google-developers/livedata-with-snackbar-navigation-and-other-events-the-singleliveevent-case-ac2622673150)
 */
abstract class ViewEvent

abstract class ViewEventWithScope: ViewEvent() {
    lateinit var scope: CoroutineScope
}

interface ContextExecutor {
    operator fun invoke(context: Context)
}

interface ActivityExecutor {
    operator fun invoke(activity: BaseUIActivity<*, *>)
}

interface FragmentExecutor {
    operator fun invoke(fragment: BaseUIFragment<*, *>)
}
