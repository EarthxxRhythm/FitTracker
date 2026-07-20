import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppRoutes } from '../app/AppRoutes';
import LaunchRequestStore from '../app/LaunchRequestStore';

const DOMAIN = 0x0000;

interface EntryLaunchParameters {
  devSeed?: string
}

export function resolveInitialPage(isLoggedIn: boolean): string {
  return AppRoutes.STARTUP
}

export default class EntryAbility extends UIAbility {
  private launchDebugSeedKey: string = '';

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const launchParameters: EntryLaunchParameters | undefined = want.parameters as EntryLaunchParameters | undefined
    this.launchDebugSeedKey = launchParameters !== undefined && launchParameters.devSeed !== undefined
      ? launchParameters.devSeed
      : '';
    hilog.info(
      DOMAIN,
      'testTag',
      'Launch want uri=%{public}s params=%{public}s',
      want.uri !== undefined ? want.uri : '',
      want.parameters !== undefined ? JSON.stringify(want.parameters) : ''
    );
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    const initialPage = resolveInitialPage(false)
    LaunchRequestStore.savePendingDebugSeedKey(this.context, this.launchDebugSeedKey)
      .catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to persist launch request. Cause: %{public}s', JSON.stringify(err));
      })
      .finally(() => {
        windowStage.loadContent(initialPage, (err) => {
          if (err.code) {
            hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
            return;
          }
          hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
        });
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
