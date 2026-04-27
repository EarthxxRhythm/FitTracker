# HarmonyOS + TypeScript 项目规则

## 技术栈
- 平台: HarmonyOS (API 9+ / API 10+)
- 语言: ArkTS (TypeScript 超集)
- UI 框架: ArkUI 声明式开发范式
- 构建工具: hvigor
- 包管理: ohpm

## 编码规范

### 命名约定
- **文件名**: 使用 PascalCase，如 `MyComponent.ets`
- **组件名**: 使用 PascalCase，如 `@Component struct MyComponent`
- **变量/函数**: 使用 camelCase，如 `userName`、`fetchData()`
- **常量**: 使用 UPPER_SNAKE_CASE，如 `MAX_RETRY_COUNT`
- **状态变量**: 添加 `@State`、`@Prop`、`@Link` 等装饰器前缀

### 组件开发
- 优先使用声明式 UI 范式，避免混合使用命令式 API
- 组件应保持单一职责，行数不超过 300 行
- 使用 `@Reusable` 装饰器标记可复用组件以优化性能
- 复杂页面拆分为多个子组件，通过 `@Prop` / `@Link` 传递数据

```typescript
// ✅ 推荐
@Reusable
@Component
struct UserCard {
  @Prop userName: string = ''
  @Prop avatar: string = ''
  
  build() {
    Row() {
      Image(this.avatar)
        .width(40)
        .height(40)
        .borderRadius(20)
      Text(this.userName)
        .fontSize(16)
        .margin({ left: 8 })
    }
  }
}
````

### 状态管理

- **@State**: 仅在组件内部使用的状态
- **@Prop**: 父组件向子组件单向传递
- **@Link**: 父子组件双向绑定
- **@Provide / @Consume**: 跨层级组件通信
- **@Observed / @ObjectLink**: 复杂对象的状态管理
- 避免不必要的状态嵌套，及时释放不用的资源

### 类型定义



```typescript
// ✅ 使用 interface 定义数据结构
interface UserInfo {
  id: string
  name: string
  avatar: string
  email?: string
}

// ✅ 使用 enum 定义常量集合
enum PageStatus {
  Loading = 0,
  Success = 1,
  Error = 2,
  Empty = 3
}

// ❌ 避免使用 any
// ✅ 对不确定类型使用联合类型或 unknown
function processData(data: unknown): void {
  if (typeof data === 'string') {
    // 安全处理
  }
}
```

### 文件结构

text

```
entry/src/main/ets/
├── common/           # 公共工具类、常量
├── components/       # 通用组件
├── pages/           # 页面
├── viewmodel/       # 视图模型
├── model/           # 数据模型
├── service/         # 网络请求、API 服务
└── utils/           # 工具函数
```

## 最佳实践

### 性能优化

- 使用 `LazyForEach` 替代 `ForEach` 处理长列表 (超过 100 条)
- 为图片设置固定宽高，避免不必要的重排
- 使用 `@Reusable` 标记频繁创建的组件
- 合理使用 `aboutToAppear()` 和 `aboutToDisappear()` 生命周期



```typescript
// ✅ 推荐：长列表使用 LazyForEach
LazyForEach(this.dataSource, (item: ItemData, index: number) => {
  ListItem() {
    ItemRow({ item: item })
  }
}, (item: ItemData) => item.id)
```

### 异步处理

- 统一使用 `async/await` 处理异步操作
- 网络请求添加超时和重试机制
- 在 `aboutToAppear` 中发起数据请求
- 使用 try\-catch 捕获所有异步异常



```typescript
@Component
struct MainPage {
  @State dataList: ItemData[] = []
  @State isLoading: boolean = true
  
  async aboutToAppear() {
    try {
      this.dataList = await this.fetchData()
    } catch (error) {
      console.error('Failed to load data:', error)
    } finally {
      this.isLoading = false
    }
  }
  
  private async fetchData(): Promise<ItemData[]> {
    const response = await http.createHttp().request(
      'https://api.example.com/data',
      { connectTimeout: 5000, readTimeout: 10000 }
    )
    return JSON.parse(response.result as string)
  }
}
```

### 路由导航

- 使用 `router.pushUrl()` / `router.replaceUrl()` 进行页面跳转
- 页面参数通过 `router.getParams()` 获取
- 在 `module.json5` 中配置所有路由页面

### 资源管理

- 图片资源统一放在 `src/main/resources/base/media/`
- 字符串使用 `$r('app.string.xxx')` 国际化引用
- 颜色/尺寸使用 `$r('app.color.xxx')` 统一管理

## 禁止事项

- ❌ 不要在 `build()` 方法中编写业务逻辑
- ❌ 不要在组件内直接发起网络请求（应抽离到 service 层）
- ❌ 不要硬编码字符串/颜色/尺寸值
- ❌ 不要混合使用声明式和命令式 UI API
- ❌ 避免在 `aboutToAppear` 中进行耗时操作（应使用异步）
- ❌ 不要忽略组件生命周期管理

## 调试与测试

- 使用 `hilog` 进行日志输出，按级别分类
- 单元测试使用 `@ohos/hypium` 框架
- 使用 DevEco Studio 的 Profiler 进行性能分析

## 上下文说明

- 目标 API Level: 10+
- 最低兼容版本: HarmonyOS 3.0
- 支持设备类型: Phone / Tablet / 2in1
- UI 适配方案: 基于 vp 单位的响应式布局
