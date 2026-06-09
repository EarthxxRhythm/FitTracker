/**
 * PrimaryDestinationStrip -- compact navigation strip for the four main product surfaces.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../app/AppRoutes'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../common/styles/DesignTokens'

interface PrimaryDestinationItem {
  key: string
  label: string
  note: string
  route: string
}

function createPrimaryDestinationItem(
  key: string,
  label: string,
  note: string,
  route: string
): PrimaryDestinationItem {
  const item: PrimaryDestinationItem = {
    key: key,
    label: label,
    note: note,
    route: route
  }
  return item
}

const PRIMARY_DESTINATION_ITEMS: PrimaryDestinationItem[] = [
  createPrimaryDestinationItem('home', '训练', '今日主线', AppRoutes.HOME),
  createPrimaryDestinationItem('library', '动作库', '搜索筛选', AppRoutes.EXERCISE_LIBRARY),
  createPrimaryDestinationItem('review', '回顾', '趋势与备份', AppRoutes.REVIEW_HOME),
  createPrimaryDestinationItem('membership', '权益', '升级结构', AppRoutes.MONETIZATION_HUB)
]

@Component
export struct PrimaryDestinationStrip {
  @Prop currentKey: string = 'home'

  private isCurrent(item: PrimaryDestinationItem): boolean {
    return item.key === this.currentKey
  }

  private getTileBackgroundColor(item: PrimaryDestinationItem): string {
    if (this.isCurrent(item)) {
      return ColorTokens.PRIMARY
    }
    return ColorTokens.SURFACE_SECONDARY
  }

  private getTileBorderColor(item: PrimaryDestinationItem): string {
    if (this.isCurrent(item)) {
      return ColorTokens.PRIMARY
    }
    return ColorTokens.BORDER_SUBTLE
  }

  private getTileLabelColor(item: PrimaryDestinationItem): string {
    if (this.isCurrent(item)) {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    return ColorTokens.TEXT_PRIMARY
  }

  private getTileNoteColor(item: PrimaryDestinationItem): string {
    if (this.isCurrent(item)) {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    return ColorTokens.TEXT_SECONDARY
  }

  private openRoute(item: PrimaryDestinationItem): void {
    if (this.isCurrent(item)) {
      return
    }
    try {
      router.replaceUrl({ url: item.route })
    } catch (error) {
      // stay on current page
    }
  }

  build() {
    Column({ space: SpacingTokens.SM }) {
      Row() {
        Text('主导航')
          .fontSize(FontTokens.MICRO_SIZE)
          .fontWeight(FontTokens.MICRO_WEIGHT)
          .fontColor(ColorTokens.TEXT_TERTIARY)

        Blank()
      }
      .width('100%')

      Scroll() {
        Row({ space: SpacingTokens.SM }) {
          ForEach(PRIMARY_DESTINATION_ITEMS, (item: PrimaryDestinationItem) => {
            Button({ type: ButtonType.Normal }) {
              Column({ space: SpacingTokens.XS }) {
                Text(item.label)
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.getTileLabelColor(item))

                Text(item.note)
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontColor(this.getTileNoteColor(item))
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            .width(132)
            .height(TouchTokens.BUTTON_HEIGHT_LARGE + 8)
            .padding({
              left: SpacingTokens.MD,
              right: SpacingTokens.MD,
              top: SpacingTokens.SM,
              bottom: SpacingTokens.SM
            })
            .backgroundColor(this.getTileBackgroundColor(item))
            .border({
              width: 1,
              color: this.getTileBorderColor(item)
            })
            .borderRadius(RadiusTokens.MD)
            .onClick(() => {
              this.openRoute(item)
            })
          }, (item: PrimaryDestinationItem) => item.key)
        }
        .padding({ right: SpacingTokens.SM })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
  }
}
