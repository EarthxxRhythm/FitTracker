/** PencilSettingsPage —— 设置注册页（薄壳：完整渲染 SettingsContent）。路由注册由协调者统一完成。 */
import { SettingsContent } from '../components/SettingsContent'

@Entry
@Component
struct PencilSettingsPage {
  build() {
    Column() {
      SettingsContent()
    }
  }
}
