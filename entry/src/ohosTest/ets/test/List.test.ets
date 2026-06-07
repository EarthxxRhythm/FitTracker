import abilityTest from './Ability.test'
import validationUtilsTest from './ValidationUtils.test'
import exerciseServiceTest from './ExerciseService.test'
import authServiceTest from './AuthService.test'
import sessionManagerTest from './SessionManager.test'
import workoutSessionLogicTest from './WorkoutSessionService.test'
import trainingPlanServiceTest from './TrainingPlanService.test'
import startupRoutingTest from './StartupRouting.test'
import contentRepositoryTest from './ContentRepository.test'
import contentDatabaseServiceTest from './ContentDatabaseService.test'
import goalSetupServiceTest from './GoalSetupService.test'
import goalAdjustmentPreviewServiceTest from './GoalAdjustmentPreviewService.test'
import homePlanServiceTest from './HomePlanService.test'
import userDataBackupServiceTest from './UserDataBackupService.test'
import systemBackupBridgeServiceTest from './SystemBackupBridgeService.test'
import workoutPreviewServiceTest from './WorkoutPreviewService.test'
import activeWorkoutServiceTest from './ActiveWorkoutService.test'
import workoutSummaryServiceTest from './WorkoutSummaryService.test'
import workoutRepositoryTest from './WorkoutRepository.test'
import workoutSessionEditServiceTest from './WorkoutSessionEditService.test'
import reviewDashboardServiceTest from './ReviewDashboardService.test'
import userProfileServiceTest from './UserProfileService.test'
import planEngineTest from './PlanEngine.test'
import statsDashboardServiceTest from './StatsDashboardService.test'
import personalRecordServiceTest from './PersonalRecordService.test'
import persistenceFallbackServiceTest from './PersistenceFallbackService.test'
import exerciseMediaResolverServiceTest from './ExerciseMediaResolverService.test'
import syncServiceTest from './SyncService.test'
import authSessionFlowTest from './AuthSessionFlow.test'
import targetLoopFlowTest from './TargetLoopFlow.test'
import authRoutingFlowTest from './AuthRoutingFlow.test'

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
  contentDatabaseServiceTest()
  goalSetupServiceTest()
  goalAdjustmentPreviewServiceTest()
  homePlanServiceTest()
  userDataBackupServiceTest()
  systemBackupBridgeServiceTest()
  workoutPreviewServiceTest()
  activeWorkoutServiceTest()
  workoutSummaryServiceTest()
  workoutRepositoryTest()
  workoutSessionEditServiceTest()
  reviewDashboardServiceTest()
  userProfileServiceTest()
  planEngineTest()
  statsDashboardServiceTest()
  personalRecordServiceTest()
  persistenceFallbackServiceTest()
  exerciseMediaResolverServiceTest()
  syncServiceTest()
  authSessionFlowTest()
  targetLoopFlowTest()
  authRoutingFlowTest()
}
