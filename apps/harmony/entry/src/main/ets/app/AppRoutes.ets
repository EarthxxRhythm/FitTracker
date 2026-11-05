/**
 * AppRoutes -- 兼容 re-export 壳。
 *
 * 常量本体已下沉到 common/AppRoutes.ets：shared 与 common 层不应为了读常量而
 * import app（app 是页面层）。本文件只为既有 features→app/AppRoutes 的引用保留
 * 解析路径，新代码请直接引用 common/AppRoutes。
 */
export { AppRoutes } from '../common/AppRoutes'
