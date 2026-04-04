/**
 * Doc feedback events for PostHog (posthog-docusaurus injects window.posthog).
 * @see https://posthog.com/docs/libraries/js
 */

import {
  capturePosthogEvent,
  getPageTelemetryProps,
} from '@site/src/utils/telemetry';

/**
 * @param {object} props
 * @param {'yes'|'no'} props.helpful
 * @param {string} [props.pageId]
 * @param {string} [props.permalink]
 * @param {string} [props.title]
 * @param {'card'|'aside'} [props.variant]
 */
export function captureDocsHelpfulVote(props) {
  capturePosthogEvent(
    'docs_helpful_vote',
    getPageTelemetryProps({
      helpful: props.helpful,
      page_id: props.pageId,
      permalink: props.permalink,
      title: props.title,
      variant: props.variant ?? 'card',
    }),
  );
}

/**
 * @param {object} props
 * @param {'yes'|'no'} props.helpful
 * @param {string} props.comment
 * @param {string} [props.pageId]
 * @param {string} [props.permalink]
 * @param {string} [props.title]
 * @param {'card'|'aside'} [props.variant]
 */
export function captureDocsHelpfulSubmit(props) {
  capturePosthogEvent(
    'docs_helpful_submit',
    getPageTelemetryProps({
      helpful: props.helpful,
      comment: props.comment,
      comment_length: props.comment.length,
      page_id: props.pageId,
      permalink: props.permalink,
      title: props.title,
      variant: props.variant ?? 'card',
    }),
  );
}
