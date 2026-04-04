/**
 * PostHog helpers (posthog-docusaurus injects window.posthog when configured).
 * @see https://posthog.com/docs/libraries/js
 */

/**
 * @returns {import('posthog-js').PostHog | null}
 */
export function getPosthog() {
  if (typeof window === 'undefined') return null;
  const ph = window.posthog;
  if (!ph || typeof ph.capture !== 'function') return null;
  return ph;
}

/**
 * @param {string} eventName
 * @param {Record<string, unknown>} [properties]
 */
export function capturePosthogEvent(eventName, properties = {}) {
  const ph = getPosthog();
  if (!ph) return;
  ph.capture(eventName, properties);
}

/**
 * Merges caller props with default page context. Uses nullish coalescing for
 * `permalink` and `title` so missing overrides keep browser defaults.
 *
 * @param {Record<string, unknown>} [overrides]
 */
export function getPageTelemetryProps(overrides = {}) {
  const defaultPermalink =
    typeof window !== 'undefined' ? window.location?.pathname : undefined;
  const defaultTitle =
    typeof document !== 'undefined' ? document.title : undefined;

  return {
    ...overrides,
    permalink: overrides.permalink ?? defaultPermalink,
    title: overrides.title ?? defaultTitle,
  };
}
