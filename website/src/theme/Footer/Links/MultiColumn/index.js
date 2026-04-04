/**
 * Footer link columns — desktop: classic grid; narrow viewports: collapsible sections.
 */
import React, { useLayoutEffect, useState } from 'react';
import clsx from 'clsx';
import { ThemeClassNames } from '@docusaurus/theme-common';
import LinkItem from '@theme/Footer/LinkItem';
import OriginalFooterLinksMultiColumn from '@theme-original/Footer/Links/MultiColumn';

const MOBILE_FOOTER_MQ = '(max-width: 996px)';

function ColumnLinkItem({ item }) {
  return item.html ? (
    <li
      className={clsx('footer__item', item.className)}
      // eslint-disable-next-line react/no-danger
      dangerouslySetInnerHTML={{ __html: item.html }}
    />
  ) : (
    <li key={item.href ?? item.to} className="footer__item">
      <LinkItem item={item} />
    </li>
  );
}

function FooterLinksAccordion({ columns }) {
  return (
    <div className="row footer__links footer__links--accordion">
      {columns.map((column, i) => (
        <details
          key={i}
          className={clsx(
            ThemeClassNames.layout.footer.column,
            'col footer__col footer__accordionSection',
            column.className,
          )}>
          <summary className="footer__accordionSummary">
            <span className="footer__title footer__accordionTitle">{column.title}</span>
            <span className="footer__accordionChevron" aria-hidden />
          </summary>
          <ul className="footer__items clean-list footer__accordionList">
            {column.items.map((item, j) => (
              <ColumnLinkItem key={j} item={item} />
            ))}
          </ul>
        </details>
      ))}
    </div>
  );
}

export default function FooterLinksMultiColumn({ columns }) {
  const [{ mounted, isMobile }, setLayout] = useState({
    mounted: false,
    isMobile: false,
  });

  useLayoutEffect(() => {
    const mql = window.matchMedia(MOBILE_FOOTER_MQ);
    setLayout({ mounted: true, isMobile: mql.matches });
    const onChange = () =>
      setLayout((prev) => ({ ...prev, isMobile: mql.matches }));
    mql.addEventListener('change', onChange);
    return () => mql.removeEventListener('change', onChange);
  }, []);

  if (!mounted || !isMobile) {
    return <OriginalFooterLinksMultiColumn columns={columns} />;
  }

  return <FooterLinksAccordion columns={columns} />;
}
