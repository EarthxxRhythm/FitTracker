/**
 * LaunchRequestStore -- persists one-shot launch requests across ability and UI runtime boundaries.
 */
import { Context } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

const STORE_NAME: string = 'fit_tracker_launch_request'
const KEY_PENDING_DEBUG_SEED: string = 'pending_debug_seed'
const KEY_PENDING_TEST_MODE: string = 'pending_test_mode'

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

  /** 测试模式（`--ps testMode=sandbox`）：启动参数落盘 → 消费端强制沙盒，跳过真实登录验证。 */
  async savePendingTestMode(context: Context, mode: string): Promise<void> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_PENDING_TEST_MODE, mode)
      await prefs.flush()
    } catch (error) {
    }
  }

  async consumePendingTestMode(context: Context): Promise<string> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME)
      const mode: string = await prefs.get(KEY_PENDING_TEST_MODE, '') as string
      if (mode.length > 0) {
        await prefs.put(KEY_PENDING_TEST_MODE, '')
        await prefs.flush()
      }
      return mode
    } catch (error) {
      return ''
    }
  }
}

export default new LaunchRequestStore()
