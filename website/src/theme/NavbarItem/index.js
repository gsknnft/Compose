/**
 * Swizzled so `ComponentTypes` always resolves to our extended map (custom navbar items).
 * @see https://github.com/facebook/docusaurus/issues/7227
 */
import React from 'react';
import ComponentTypes from './ComponentTypes';

function normalizeComponentType(type, props) {
  if (!type || type === 'default') {
    return 'items' in props ? 'dropdown' : 'default';
  }
  return type;
}

export default function NavbarItem({type, ...props}) {
  const componentType = normalizeComponentType(type, props);
  const NavbarItemComponent = ComponentTypes[componentType];
  if (!NavbarItemComponent) {
    throw new Error(`No NavbarItem component found for type "${componentType}".`);
  }
  return <NavbarItemComponent {...props} />;
}
