/**
 * HomePage -- registered home route wrapper for the redesigned today-first homepage.
 * Function #8: today training entry.
 */
import { HomePageV2 } from '../features/home/pages/HomePageV2'

@Entry
@Component
export struct HomePage {
  build() {
    Column() {
      HomePageV2()
    }
    .width('100%')
    .height('100%')
  }
}
