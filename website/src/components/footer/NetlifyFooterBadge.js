import React from 'react';

/**
 * Netlify Open Source plan attribution — keep visible and linked to netlify.com.
 */
export default function NetlifyFooterBadge() {
  return (
    <div className="netlifyBadge">
      <a
        href="https://www.netlify.com"
        target="_blank"
        rel="noopener noreferrer">
        <span className="badgeDot" />
        <span className="badgeText">
          This site is powered by{' '}
          <span className="badgeTextNetlify">Netlify</span>
        </span>
      </a>
    </div>
  );
}
