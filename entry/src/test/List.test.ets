import localUnitTest from './LocalUnit.test'
import validationUtilsTest from './ValidationUtils.test'
import authServiceTest from './AuthService.test'

export default function testsuite() {
  localUnitTest()
  validationUtilsTest()
  authServiceTest()
}
