/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */



import { Constants } from '../common/Constants';
import { ExerciseLibraryPage } from './ExerciseLibraryPage';
import { Index } from './Index';
import { ProfilePage } from './ProfilePage';
import { WorkoutRecorderPage } from './WorkoutRecorderPage';

function initTabTuData(): BottomTabModel[] {
  let tabTuDataArray: BottomTabModel[] = [];
  TabTuItemData.forEach((item: BottomTabModel) => {
    tabTuDataArray.push(new BottomTabModel(item.defaultImage, item.selectImage, item.title, item.middleMode));
  })
  return tabTuDataArray;
}

export class BottomTabModel {
  selectImage: Resource;
  defaultImage: Resource;
  middleMode: boolean;
  title: string | Resource;
  isSelected: boolean = false;

  constructor(selectImage: Resource, defaultImage: Resource, title: string | Resource, middleMode = false) {
    this.selectImage = selectImage;
    this.defaultImage = defaultImage;
    this.title = title;
    this.middleMode = middleMode;
  }
}

const TabTuItemData: BottomTabModel[] = [
  new BottomTabModel($rawfile('首页.svg'), $rawfile('首页_选中 .svg'), '首页'),
  new BottomTabModel($rawfile('日历.svg'), $rawfile('日历.svg'), '计划'),
  new BottomTabModel($rawfile('闪电.svg'), $rawfile('闪电_选中.svg'), '', true),
  new BottomTabModel($rawfile('tab哑铃.svg'), $rawfile('tab哑铃_选中.svg'), '动作库'),
  new BottomTabModel($rawfile('我的.svg'), $rawfile('我的_选中.svg'),'我的')
];
@Entry
@Component
struct RudderStyleTab {
  @State tabArray: Array<BottomTabModel> = initTabTuData();
  @State currentIndex: number = 0;
  @State iconOffset: number = 0;
  @State initNumber: number = 0;
  private controller: TabsController = new TabsController();

  // [Start Builder_tab]
  @Builder
  Tab(selectImage: Resource, defaultImage: Resource, title: string | Resource, middleMode: boolean, index: number) {
    Column() {
      if (index === Constants.TAB_INDEX_TWO) {
        Image(this.currentIndex === Constants.TAB_INDEX_TWO ? selectImage : defaultImage)
          .size({ width: 56, height: 56 })
          .offset({ y: -20 })
      } else {
        Image(this.currentIndex === index ? selectImage : defaultImage)
          .size({ width: 22, height: 22 })
          .offset({
            y: (this.currentIndex === index && this.currentIndex !== Constants.TAB_INDEX_TWO)
              ? this.iconOffset : this.initNumber
          })
          .objectFit(ImageFit.Contain)
          .animation({
            duration: Constants.ANIMATION_DURATION,
            curve: Curve.Ease,
            playMode: PlayMode.Normal
          })
      }

      if (!middleMode) {
        Text(title)
          .fontSize(15)
          .margin({ top: 6 })
          .fontColor(this.currentIndex === index ? '#3388ff' : '#ffffffff')
      }
    }
    .padding({ top: 11 })
    .width('100%')
    .backgroundColor('#F3F4F5')
    .height(90)
    .translate({ y: 40 })
    .onClick(() => {
      this.currentIndex = index;
      this.controller.changeIndex(index);
      this.iconOffset = Constants.ICON_Offset;
    })
    .backgroundColor('#1a1a1a')
  }
  // [End Builder_tab]

  build() {
    Column() {
      Stack({ alignContent: Alignment.BottomStart }) {
        // [Start Rudder_style_tab_tabs]
        Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
          ForEach(this.tabArray, (item: BottomTabModel, index: number) => {
            TabContent() {
              if (index == 0) {
                Index()
              } else if (index == 1){

              } else if (index == 2){
                WorkoutRecorderPage()
              } else if (index == 3){
                ExerciseLibraryPage()
              } else if (index == 4){
                ProfilePage()
              }
            }
          }, (item: BottomTabModel, index: number) => JSON.stringify(item) + index)
        }
        // [End Rudder_style_tab_tabs]
        .scrollable(false)
        .barHeight(this.initNumber)
        .animationDuration(Constants.ANIMATION_DURATION)
        // [Start Rudder_style_tab_flex]
        Flex() {
          ForEach(this.tabArray, (item: BottomTabModel, index: number) => {
            this.Tab(item.selectImage, item.defaultImage, item.title, item.middleMode, index)
          }, (item: BottomTabModel, index: number) => JSON.stringify(item) + index)
        }
        // [End Rudder_style_tab_flex]
      }
    }
    .height('100%')
  }
}