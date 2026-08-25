/**
 * FavoriteExerciseService —— 动作收藏持久化服务
 *
 * 提供动作库「收藏」状态的本地持久化（本地单用户全局收藏）。
 * 同步读内存缓存，异步写 preferences；写入失败不影响 UI 主流程。
 */
import { preferences } from '@kit.ArkData'

const STORE_NAME = 'fit_tracker_favorites'
const KEY_FAVORITE_IDS = 'favorite_ids'

class FavoriteExerciseService {
  private favoriteIds: string[] = []

  /**
   * 从 preferences 恢复收藏集合到内存。
   */
  async load(): Promise<void> {
    try {
      const context: Context = getContext()
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      const json = await prefs.get(KEY_FAVORITE_IDS, '[]') as string
      this.favoriteIds = this.parseIds(json)
    } catch (e) {
      // 持久化失败不影响 UI 主流程，保留内存中的现有收藏。
    }
  }

  /**
   * 判断某个动作是否已收藏。
   */
  isFavorite(exerciseId: string): boolean {
    return this.favoriteIds.indexOf(exerciseId) >= 0
  }

  /**
   * 切换收藏状态，返回切换后的新状态，并异步持久化。
   */
  toggleFavorite(exerciseId: string): boolean {
    const index = this.favoriteIds.indexOf(exerciseId)
    if (index >= 0) {
      this.favoriteIds.splice(index, 1)
    } else {
      this.favoriteIds.push(exerciseId)
    }
    this.persist()
    return index < 0
  }

  /**
   * 返回已收藏动作 id 列表的副本。
   */
  getFavoriteIds(): string[] {
    const ids: string[] = []
    for (let index = 0; index < this.favoriteIds.length; index++) {
      ids.push(this.favoriteIds[index])
    }
    return ids
  }

  /**
   * 返回已收藏动作数量。
   */
  getFavoriteCount(): number {
    return this.favoriteIds.length
  }

  /**
   * 将当前收藏集合异步写入 preferences。
   */
  private async persist(): Promise<void> {
    try {
      const context: Context = getContext()
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_FAVORITE_IDS, JSON.stringify(this.favoriteIds))
      await prefs.flush()
    } catch (e) {
      // 持久化失败不影响 UI 主流程。
    }
  }

  /**
   * 将持久化的 JSON 字符串恢复为 string[]，非法内容安全回退为空数组。
   */
  private parseIds(json: string): string[] {
    if (json.length === 0) {
      return []
    }
    try {
      const parsed = JSON.parse(json) as string[]
      if (!Array.isArray(parsed)) {
        return []
      }
      const ids: string[] = []
      for (let index = 0; index < parsed.length; index++) {
        ids.push(parsed[index])
      }
      return ids
    } catch (e) {
      return []
    }
  }
}

export default new FavoriteExerciseService()
