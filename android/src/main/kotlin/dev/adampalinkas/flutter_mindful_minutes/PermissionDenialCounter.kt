package dev.adampalinkas.flutter_mindful_minutes

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

// Creates a DataStore instance at the top level to ensure it is a singleton
private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "permission_prefs")

class PermissionDenialCounter(private val context: Context) {

    companion object {
        // Android typically blocks permission dialogs after 2 denials
        private const val DEFAULT_DENIAL_LIMIT = 2

        fun getDenialCountKey(permissionName: String) = intPreferencesKey("denial_count_$permissionName")
    }

    /**
     * Increments the denial count for a specific permission.
     */
    suspend fun incrementDenialCount(permissionName: String) {
        val key = getDenialCountKey(permissionName)
        context.dataStore.edit { preferences ->
            val currentCount = preferences[key] ?: 0
            preferences[key] = currentCount + 1
        }
    }

    /**
     * Checks if the denial count has reached or exceeded the specified limit.
     */
    suspend fun isOverLimit(permissionName: String, limit: Int = DEFAULT_DENIAL_LIMIT): Boolean {
        val key = getDenialCountKey(permissionName)
        val currentCount = context.dataStore.data.map { preferences ->
            preferences[key] ?: 0
        }.first()

        return currentCount >= limit
    }

    /**
     * Resets the denial count for a permission.
     * Useful if the user eventually grants the permission via Settings.
     */
    suspend fun resetCounter(permissionName: String) {
        val key = getDenialCountKey(permissionName)
        context.dataStore.edit { preferences ->
            preferences.remove(key)
        }
    }

    /**
     * Retrieves the current denial count for a permission.
     */
    suspend fun getDenialCount(permissionName: String): Int {
        val key = getDenialCountKey(permissionName)
        return context.dataStore.data.map { preferences ->
            preferences[key] ?: 0
        }.first()
    }
}