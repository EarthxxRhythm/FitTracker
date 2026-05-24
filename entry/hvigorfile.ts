import { hapTasks } from '@ohos/hvigor-ohos-plugin';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { hvigorCore } from '@ohos/hvigor/src/base/external/core/hvigor-core';
import type { HvigorNode, HvigorTaskContext } from '@ohos/hvigor';

function resolveBuildTarget(): string {
  const moduleValue = hvigorCore.getExtraConfig().get('module');
  if (moduleValue === undefined) {
    return 'default';
  }

  const targetSeparator = '@';
  const targetIndex = moduleValue.indexOf(targetSeparator);
  if (targetIndex < 0) {
    return 'default';
  }

  return moduleValue.substring(targetIndex + targetSeparator.length);
}

function runNodeTool(taskContext: HvigorTaskContext, scriptRelativePath: string, label: string): void {
  const projectRoot = resolve(taskContext.modulePath, '..');
  const scriptPath = resolve(projectRoot, scriptRelativePath);

  console.log(`[FitTracker] ${label}`);
  execFileSync('node', [scriptPath], {
    cwd: projectRoot,
    stdio: 'inherit'
  });
}

function runFitTrackerPreBuildChecks(taskContext: HvigorTaskContext): void {
  runNodeTool(taskContext, 'tools/check-main-pages.mjs', 'check registered pages');
  runNodeTool(taskContext, 'tools/content/build-content.mjs', 'generate local exercise content');
}

function fitTrackerContentGenerator() {
  return {
    pluginId: 'fittracker-content-generator',
    apply(node: HvigorNode) {
      node.registerTask({
        name: 'generateLocalExerciseContent',
        postDependencies: [`${resolveBuildTarget()}@PreBuild`],
        run(taskContext: HvigorTaskContext) {
          runFitTrackerPreBuildChecks(taskContext);
        }
      });
    }
  };
}

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [fitTrackerContentGenerator()] /* Custom plugin to extend the functionality of Hvigor. */
}
