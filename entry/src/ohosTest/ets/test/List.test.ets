import abilityTest from './Ability.test'
import validationUtilsTest from './ValidationUtils.test'
import exerciseServiceTest from './ExerciseService.test'
import authServiceTest from './AuthService.test'
import sessionManagerTest from './SessionManager.test'
import workoutSessionLogicTest from './WorkoutSessionService.test'
import trainingPlanServiceTest from './TrainingPlanService.test'
import startupRoutingTest from './StartupRouting.test'
import contentRepositoryTest from './ContentRepository.test'
import goalSetupServiceTest from './GoalSetupService.test'
import homePlanServiceTest from './HomePlanService.test'
import workoutPreviewServiceTest from './WorkoutPreviewService.test'
import activeWorkoutServiceTest from './ActiveWorkoutService.test'
import workoutSummaryServiceTest from './WorkoutSummaryService.test'
import reviewDashboardServiceTest from './ReviewDashboardService.test'
import userProfileServiceTest from './UserProfileService.test'
import planEngineTest from './PlanEngine.test'
import statsDashboardServiceTest from './StatsDashboardService.test'

export default function testsuite(): void {
  abilityTest()
  validationUtilsTest()
  exerciseServiceTest()
  authServiceTest()
  sessionManagerTest()
  workoutSessionLogicTest()
  trainingPlanServiceTest()
  startupRoutingTest()
  contentRepositoryTest()
  goalSetupServiceTest()
  homePlanServiceTest()
  workoutPreviewServiceTest()
  activeWorkoutServiceTest()
  workoutSummaryServiceTest()
  reviewDashboardServiceTest()
  userProfileServiceTest()
  planEngineTest()
  statsDashboardServiceTest()
}
