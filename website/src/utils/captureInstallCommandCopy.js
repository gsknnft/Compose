/**
 * PostHog: when users copy installation snippets from the docs (Installation page
 * fenced code blocks). Matched by normalized code content.
 */

import {
  capturePosthogEvent,
  getPageTelemetryProps,
} from '@site/src/utils/telemetry';

const EVENT = 'docs_install_command_copy';

function normalizeInstallCode(raw) {
  if (typeof raw !== 'string') return '';
  return raw.trim().replace(/\r\n/g, '\n');
}

/**
 * @param {string} code — CodeBlock copy metadata (plain string)
 * @returns {'compose_cli_npx'|'compose_cli_global'|'foundry_forge'|'hardhat_npm'|null}
 */
function getInstallCopyTelemetryKind(code) {
  const n = normalizeInstallCode(code);
  if (n === 'npx @perfect-abstractions/compose-cli init') {
    return 'compose_cli_npx';
  }
  if (n.startsWith('forge install Perfect-Abstractions/Compose@')) {
    return 'foundry_forge';
  }
  if (n === 'npm install @perfect-abstractions/compose') {
    return 'hardhat_npm';
  }
  return null;
}

/**
 * @param {string} code
 */
export function captureInstallCommandCopyIfTracked(code) {
  const install_command_kind = getInstallCopyTelemetryKind(code);
  if (!install_command_kind) return;
  capturePosthogEvent(
    EVENT,
    getPageTelemetryProps({ install_command_kind }),
  );
}
