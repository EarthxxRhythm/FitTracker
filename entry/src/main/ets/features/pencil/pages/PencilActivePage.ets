/** PencilActivePage - 训练中注册页（薄壳：完整渲染 ActiveContent，训练预览页跳转至此）。 */
import { ActiveContent } from '../components/ActiveContent'

@Entry
@Component
struct PencilActivePage {
  build() {
    Column() {
      ActiveContent()
    }
  }
}
