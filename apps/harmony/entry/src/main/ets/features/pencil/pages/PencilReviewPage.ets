/** PencilReviewPage - 复盘注册页（薄壳：完整渲染 ReviewContent，供独立路由/兜底回退直达）。 */
import { ReviewContent } from '../components/ReviewContent'

@Entry
@Component
struct PencilReviewPage {
  build() {
    Column() {
      ReviewContent()
    }
  }
}
