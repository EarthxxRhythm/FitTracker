/**
 * GoalRepository - local user goal repository.
 *
 * Feature #6: startup route uses saved goal state.
 */
import { preferences } from '@kit.ArkData'
import { FitTrackerStores } from '../../app/AppState'
import { UserGoal, createUserGoal } from '../models/TrainingModels'

const KEY_CURRENT_GOAL = 'current_goal'

class GoalRepository {
  private currentGoal: UserGoal | undefined = undefined
  private lastPersistenceError: string = ''

  saveLocalGoal(goal: UserGoal): void {
    this.currentGoal = this.copyGoal(goal)
  }

  getLocalGoal(): UserGoal | undefined {
    if (this.currentGoal === undefined) {
      return undefined
    }
    return this.copyGoal(this.currentGoal)
  }

  hasLocalGoal(): boolean {
    return this.currentGoal !== undefined
  }

  clearLocal(): void {
    this.currentGoal = undefined
  }

  getLastPersistenceError(): string {
    return this.lastPersistenceError
  }

  async saveGoal(context: Context, goal: UserGoal): Promise<void> {
    this.saveLocalGoal(goal)
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, FitTrackerStores.GOAL)
      await prefs.put(KEY_CURRENT_GOAL, JSON.stringify(this.copyGoal(goal)))
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'save_goal_failed'
    }
  }

  async loadGoal(context: Context): Promise<UserGoal | undefined> {
    if (this.currentGoal !== undefined) {
      return this.copyGoal(this.currentGoal)
    }

    let value: string = ''
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, FitTrackerStores.GOAL)
      value = await prefs.get(KEY_CURRENT_GOAL, '') as string
    } catch (error) {
      this.lastPersistenceError = 'load_goal_failed'
      return undefined
    }
    if (value.length === 0) {
      return undefined
    }

    try {
      const parsedGoal = JSON.parse(value) as UserGoal
      const goal: UserGoal = this.copyGoal(parsedGoal)
      this.currentGoal = this.copyGoal(goal)
      return goal
    } catch (e) {
      return undefined
    }
  }

  async hasSavedGoal(context: Context): Promise<boolean> {
    const goal: UserGoal | undefined = await this.loadGoal(context)
    return goal !== undefined
  }

  async clearSavedGoal(context: Context): Promise<void> {
    this.clearLocal()
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, FitTrackerStores.GOAL)
      await prefs.delete(KEY_CURRENT_GOAL)
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'clear_goal_failed'
    }
  }

  private copyGoal(source: UserGoal): UserGoal {
    return createUserGoal(
      source.goalId,
      source.goalType,
      source.level,
      source.weeklyDays,
      source.sessionMinutes,
      this.copyStringArray(source.equipmentIds),
      this.copyStringArray(source.restrictedMuscleIds),
      source.createdAt,
      source.updatedAt
    )
  }

  private copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }
}

export default new GoalRepository()
