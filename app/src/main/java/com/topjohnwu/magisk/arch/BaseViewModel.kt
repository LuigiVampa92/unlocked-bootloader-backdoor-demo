package com.topjohnwu.magisk.arch

import android.Manifest
import android.os.Build
import androidx.annotation.CallSuper
import androidx.core.graphics.Insets
import androidx.databinding.Bindable
import androidx.databinding.Observable
import androidx.databinding.PropertyChangeRegistry
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.navigation.NavDirections
import com.topjohnwu.magisk.BR
import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.core.base.BaseActivity
import com.topjohnwu.magisk.events.*
import com.topjohnwu.magisk.utils.ObservableHost
import com.topjohnwu.magisk.utils.set
import kotlinx.coroutines.Job
import org.koin.core.KoinComponent

abstract class BaseViewModel(
    initialState: State = State.LOADING
) : ViewModel(), ObservableHost, KoinComponent {

    override var callbacks: PropertyChangeRegistry? = null

    enum class State {
        LOADED, LOADING, LOADING_FAILED
    }

    @get:Bindable
    val loading get() = state == State.LOADING
    @get:Bindable
    val loaded get() = state == State.LOADED
    @get:Bindable
    val loadFailed get() = state == State.LOADING_FAILED

    val isConnected get() = Info.isConnected
    val viewEvents: LiveData<ViewEvent> get() = _viewEvents

    @get:Bindable
    var insets = Insets.NONE
        set(value) = set(value, field, { field = it }, BR.insets)

    var state= initialState
        set(value) = set(value, field, { field = it }, BR.loading, BR.loaded, BR.loadFailed)

    private val _viewEvents = MutableLiveData<ViewEvent>()
    private var runningJob: Job? = null
    private val refreshCallback = object : Observable.OnPropertyChangedCallback() {
        override fun onPropertyChanged(sender: Observable?, propertyId: Int) {
            requestRefresh()
        }
    }

    init {
        isConnected.addOnPropertyChangedCallback(refreshCallback)
    }

    /** This should probably never be called manually, it's called manually via delegate. */
    @Synchronized
    fun requestRefresh() {
        if (runningJob?.isActive == true) {
            return
        }
        runningJob = refresh()
    }

    protected open fun refresh(): Job? = null

    @CallSuper
    override fun onCleared() {
        isConnected.removeOnPropertyChangedCallback(refreshCallback)
        super.onCleared()
    }

    fun withView(action: BaseActivity.() -> Unit) {
        ViewActionEvent(action).publish()
    }

    fun withPermission(permission: String, callback: (Boolean) -> Unit) {
        PermissionEvent(permission, callback).publish()
    }

    fun withExternalRW(callback: () -> Unit) {
        withPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) {
            if (!it) {
                SnackbarEvent(R.string.external_rw_permission_denied).publish()
            } else {
                callback()
            }
        }
    }

    fun back() = BackPressEvent().publish()

    fun <Event : ViewEvent> Event.publish() {
        _viewEvents.postValue(this)
    }

    fun <Event : ViewEventWithScope> Event.publish() {
        scope = viewModelScope
        _viewEvents.postValue(this)
    }

    fun NavDirections.publish() {
        _viewEvents.postValue(NavigationEvent(this))
    }

}
