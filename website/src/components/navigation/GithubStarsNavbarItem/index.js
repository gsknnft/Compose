import React from 'react';
import clsx from 'clsx';
import NavbarNavLink from '@theme/NavbarItem/NavbarNavLink';
import {useGithubStarsCount} from '@site/src/hooks/useGithubStarsCount';
import styles from './styles.module.css';

function formatStarCount(n) {
  if (typeof n !== 'number' || !Number.isFinite(n)) return null;
  if (n < 10000) return n.toLocaleString();
  if (n < 1_000_000) return `${(n / 1000).toFixed(n % 1000 === 0 ? 0 : 1)}k`;
  return `${(n / 1_000_000).toFixed(1)}M`;
}

function StarGlyph({className}) {
  return (
    <svg
      className={className}
      width={14}
      height={14}
      viewBox="0 0 24 24"
      aria-hidden="true"
      focusable="false">
      <path
        fill="currentColor"
        d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"
      />
    </svg>
  );
}

/**
 * Navbar item: GitHub repo link with live star count (GitHub REST API).
 * Use in docusaurus.config.js: { type: 'custom-githubStars', position: 'right' }.
 */
export default function GithubStarsNavbarItem({
  mobile = false,
  position: _position,
  owner = 'Perfect-Abstractions',
  repo = 'Compose',
  className,
}) {
  const href = `https://github.com/${owner}/${repo}`;
  const {count, isLoading} = useGithubStarsCount({owner, repo});

  const label = (
    <>
      <span
        className={styles.badge}
        aria-label={
          !isLoading && count !== null ? `${count} GitHub stars` : undefined
        }>
        <StarGlyph className={styles.star} />
        <span className={styles.count}>
          {isLoading ? '…' : formatStarCount(count) ?? '—'}
        </span>
      </span>
      GitHub
    </>
  );

  const link = (
    <NavbarNavLink
      className={clsx(
        mobile ? 'menu__link' : 'navbar__item navbar__link',
        styles.link,
        className,
      )}
      href={href}
      label={label}
      target="_blank"
      rel="noopener noreferrer"
    />
  );

  if (mobile) {
    return <li className="menu__list-item">{link}</li>;
  }

  return link;
}
