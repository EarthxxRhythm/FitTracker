import localUnitTest from './LocalUnit.test'
import validationUtilsTest from './ValidationUtils.test'
import authServiceTest from './AuthService.test'
import sessionManagerTest from './SessionManager.test'
import userProfileServiceTest from './UserProfileService.test'
import trainingPlanServiceTest from './TrainingPlanService.test'
import exerciseServiceTest from './ExerciseService.test'
import startupRoutingTest from './StartupRouting.test'

export default function testsuite() {
  localUnitTest()
  validationUtilsTest()
  authServiceTest()
  sessionManagerTest()
  userProfileServiceTest()
  trainingPlanServiceTest()
  exerciseServiceTest()
  startupRoutingTest()
}
