/**
 * LaunchRequestStore -- persists one-shot launch requests across ability and UI runtime boundaries.
 */
import { Context } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

const STORE_NAME: string = 'fit_tracker_launch_request'
const KEY_PENDING_DEBUG_SEED: string = 'pending_debug_seed'

class LaunchRequestStore {
  async savePendingDebugSeedKey(context: Context, seedKey: string): Promise<void> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_PENDING_DEBUG_SEED, seedKey)
      await prefs.flush()
    } catch (error) {
    }
  }

  async consumePendingDebugSeedKey(context: Context): Promise<string> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME)
      const seedKey: string = await prefs.get(KEY_PENDING_DEBUG_SEED, '') as string
      if (seedKey.length > 0) {
        await prefs.put(KEY_PENDING_DEBUG_SEED, '')
        await prefs.flush()
      }
      return seedKey
    } catch (error) {
      return ''
    }
  }
}

export default new LaunchRequestStore()
