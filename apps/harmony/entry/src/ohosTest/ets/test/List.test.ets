import abilityTest from './Ability.test'
import validationUtilsTest from './ValidationUtils.test'
import exerciseServiceTest from './ExerciseService.test'
import authServiceTest from './AuthService.test'
import sessionManagerTest from './SessionManager.test'
import workoutSessionLogicTest from './WorkoutSessionService.test'
import trainingPlanServiceTest from './TrainingPlanService.test'
import planTabModelTest from './PlanTabModel.test'
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
import trainingDayLabelServiceTest from './TrainingDayLabelService.test'
import reviewDashboardServiceTest from './ReviewDashboardService.test'
import reviewInsightsServiceTest from './ReviewInsightsService.test'
import userProfileServiceTest from './UserProfileService.test'
import settingsServiceTest from './SettingsService.test'
import weekUtilsTest from './WeekUtils.test'
import planEngineTest from './PlanEngine.test'
import statsDashboardServiceTest from './StatsDashboardService.test'
import personalRecordServiceTest from './PersonalRecordService.test'
import bodyRecordServiceTest from './BodyRecordService.test'
import bodyMeasurementServiceTest from './BodyMeasurementService.test'
import bodyMetricsTest from './BodyMetrics.test'
import persistenceFallbackServiceTest from './PersistenceFallbackService.test'
import deviceSeedServiceTest from './DeviceSeedService.test'
import exerciseMediaResolverServiceTest from './ExerciseMediaResolverService.test'
import exerciseGifCatalogTest from './ExerciseGifCatalog.test'
import syncServiceTest from './SyncService.test'
import startupContentSyncFlowTest from './StartupContentSyncFlow.test'
import authSessionFlowTest from './AuthSessionFlow.test'
import targetLoopFlowTest from './TargetLoopFlow.test'
import authRoutingFlowTest from './AuthRoutingFlow.test'
import authFlowSandboxTest from './AuthFlowSandbox.test'
import cloudSyncServiceTest from './CloudSyncService.test'
import accountDataLifecycleTest from './AccountDataLifecycle.test'
import workoutReminderServiceTest from './WorkoutReminderService.test'
import achievementNoticeServiceTest from './AchievementNoticeService.test'
import supabaseCloudSnapshotStoreTest from './SupabaseCloudSnapshotStore.test'
import streakUtilsTest from './StreakUtils.test'

export default function testsuite(): void {
  abilityTest()
  validationUtilsTest()
  exerciseServiceTest()
  authServiceTest()
  sessionManagerTest()
  workoutSessionLogicTest()
  trainingPlanServiceTest()
  planTabModelTest()
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
  trainingDayLabelServiceTest()
  reviewDashboardServiceTest()
  reviewInsightsServiceTest()
  userProfileServiceTest()
  settingsServiceTest()
  weekUtilsTest()
  planEngineTest()
  statsDashboardServiceTest()
  personalRecordServiceTest()
  bodyRecordServiceTest()
  bodyMeasurementServiceTest()
  bodyMetricsTest()
  persistenceFallbackServiceTest()
  deviceSeedServiceTest()
  exerciseMediaResolverServiceTest()
  exerciseGifCatalogTest()
  syncServiceTest()
  startupContentSyncFlowTest()
  authSessionFlowTest()
  targetLoopFlowTest()
  authRoutingFlowTest()
  authFlowSandboxTest()
  cloudSyncServiceTest()
  accountDataLifecycleTest()
  workoutReminderServiceTest()
  achievementNoticeServiceTest()
  supabaseCloudSnapshotStoreTest()
  streakUtilsTest()
}
