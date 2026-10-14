import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppRoutes } from '../app/AppRoutes';
import LaunchRequestStore from '../app/LaunchRequestStore';
import WorkoutReminderService from '../common/services/WorkoutReminderService';
import ThirdPartyBridgeBootstrap from '../common/services/auth/ThirdPartyBridgeBootstrap';
import ThirdPartyBridgeRegistry from '../common/services/auth/ThirdPartyBridgeRegistry';

const DOMAIN = 0x0000;

interface EntryLaunchParameters {
  devSeed?: string
  testMode?: string
}
export default class EntryAbility extends UIAbility {
  private launchDebugSeedKey: string = '';
  private launchTestMode: string = '';

  private async configureWindowAndLoadContent(windowStage: window.WindowStage, initialPage: string): Promise<void> {
    try {
      const mainWindow: window.Window = await windowStage.getMainWindow()
      await mainWindow.setWindowLayoutFullScreen(true)
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#0B0F13',
        navigationBarColor: '#0B0F13',
        isStatusBarLightIcon: true,
        isNavigationBarLightIcon: true
      })
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to configure main window. Cause: %{public}s', JSON.stringify(err))
    }

    windowStage.loadContent(initialPage, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const launchParameters: EntryLaunchParameters | undefined = want.parameters as EntryLaunchParameters | undefined
    this.launchDebugSeedKey = launchParameters !== undefined && launchParameters.devSeed !== undefined
      ? launchParameters.devSeed
      : '';
    this.launchTestMode = launchParameters !== undefined && launchParameters.testMode !== undefined
      ? launchParameters.testMode
      : '';
    hilog.info(
      DOMAIN,
      'testTag',
      'Launch want uri=%{public}s params=%{public}s',
      want.uri !== undefined ? want.uri : '',
      want.parameters !== undefined ? JSON.stringify(want.parameters) : ''
    );
    try {
      // 应用为固定深色 UI：声明深色模式，让系统按深色绘制窗口外的系统区域
      // （底部手势导航区），避免浅色系统主题下底部露白；NOT_SET 跟随系统会在浅色下露白。
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    // 训练提醒冷启动校准（幂等 ensure；失败静默——启动路径不受影响）。
    WorkoutReminderService.calibrateFromLaunch(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Reminder calibration failed. Cause: %{public}s', JSON.stringify(err))
    })
    // 第三方桥注册（幂等）：冷启动即由第三方回调拉起时，需 bridge 已在册才能分派。
    // 放在既有逻辑之后，不插入既有 Promise 链。
    try {
      ThirdPartyBridgeBootstrap.initialize(this.context)
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'ThirdParty bootstrap failed. Cause: %{public}s', JSON.stringify(err))
    }
    // 本次启动若即由第三方回调拉起（冷启动路径），分派该 want。
    this.dispatchThirdPartyCallback(want)
  }

  /**
   * 热启动回调入口：第三方授权后回到本应用（不销毁 Ability 的情形）。
   * 与 onCreate 的对应逻辑同构，保证冷/热两条路径都能收到授权结果。
   */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', 'Ability onNewWant uri=%{public}s', want.uri !== undefined ? want.uri : '')
    this.dispatchThirdPartyCallback(want)
  }

  /**
   * 第三方 SDK 回调分派（失败静默，绝不阻断启动路径）。
   *
   * 安全性：ThirdPartyBridgeRegistry.dispatch 内部对每个 bridge 独立 try/catch——
   * 任一 SDK 的 handleWant 抛错不影响其余 bridge，也不影响应用启动。
   * 与 WorkoutReminderService.calibrateFromLaunch 的「失败静默」纪律一致。
   */
  private dispatchThirdPartyCallback(want: Want): void {
    ThirdPartyBridgeRegistry.dispatch(this.context, want).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'ThirdParty callback dispatch failed. Cause: %{public}s', JSON.stringify(err))
    })
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    const initialPage: string = AppRoutes.STARTUP
    LaunchRequestStore.savePendingDebugSeedKey(this.context, this.launchDebugSeedKey)
      .then(() => LaunchRequestStore.savePendingTestMode(this.context, this.launchTestMode))
      .catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to persist launch request. Cause: %{public}s', JSON.stringify(err));
      })
      .finally(() => {
        this.configureWindowAndLoadContent(windowStage, initialPage)
      });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
