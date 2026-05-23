/**
 * GoalSetupService - transforms onboarding selections into a goal.
 *
 * Feature #7: real goal setup questionnaire.
 */
import { UserGoal, createUserGoal } from '../models/TrainingModels'

class GoalSetupService {
  createGoalFromSelection(
    goalId: string,
    goalType: string,
    level: string,
    weeklyDays: number,
    sessionMinutes: number,
    equipmentIds: string[],
    restrictedMuscleIds: string[],
    now: number
  ): UserGoal {
    return createUserGoal(
      goalId,
      goalType,
      level,
      weeklyDays,
      sessionMinutes,
      this.copyStringArray(equipmentIds),
      this.copyStringArray(restrictedMuscleIds),
      now,
      now
    )
  }

  createGoalFromExistingSelection(
    existingGoal: UserGoal,
    goalType: string,
    level: string,
    weeklyDays: number,
    sessionMinutes: number,
    equipmentIds: string[],
    restrictedMuscleIds: string[],
    now: number
  ): UserGoal {
    return createUserGoal(
      existingGoal.goalId,
      goalType,
      level,
      weeklyDays,
      sessionMinutes,
      this.copyStringArray(equipmentIds),
      this.copyStringArray(restrictedMuscleIds),
      existingGoal.createdAt,
      now
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

export default new GoalSetupService()
