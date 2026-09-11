/** PencilHomePage - 首页注册页（薄壳：独立路由命中时跳转 AppShell，日常由 Tab 内 HomeContent 渲染）。 */
import { AppRoutes } from '../../../app/AppRoutes'
import { HomeContent } from '../components/HomeContent'

@Entry
@Component
struct PencilHomePage {
  aboutToAppear(): void {
    this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.APP_SHELL })
  }

  build() {
    Column() {
      HomeContent()
    }
    .width('100%')
    .height('100%')
  }
}
