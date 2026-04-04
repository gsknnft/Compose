/**
 * Footer layout — bottom meta row pairs copyright with Netlify attribution (OSS plan).
 */
import React from 'react';
import clsx from 'clsx';
import {ThemeClassNames} from '@docusaurus/theme-common';
import NetlifyFooterBadge from '../../../components/footer/NetlifyFooterBadge';

export default function FooterLayout({style, links, logo, copyright}) {
  return (
    <footer
      className={clsx(ThemeClassNames.layout.footer.container, 'footer', {
        'footer--dark': style === 'dark',
      })}>
      <div className="container container-fluid">
        {links}
        {(logo || copyright) && (
          <div className="footer__bottom">
            {logo && <div className="margin-bottom--sm">{logo}</div>}
            <div className="footer__metaRow">
              {copyright && (
                <div className="footer__copyrightCol">{copyright}</div>
              )}
              <NetlifyFooterBadge />
            </div>
          </div>
        )}
      </div>
    </footer>
  );
}
