module.exports = function docsSearch(context) {
  return {
    name: 'local-docs-search',
    async contentLoaded({allContent, actions}) {
      const version = allContent['docusaurus-plugin-content-docs']?.default?.loadedVersions?.[0];
      if (!version?.docs?.length) throw new Error('Local search requires loaded documentation metadata.');
      const items = version.docs.map(({title, description, permalink}) => ({
        title, description,
        permalink: context.siteConfig.trailingSlash ? `${permalink.replace(/\/$/, '')}/` : permalink,
      }));
      const data = await actions.createData('guides.json', JSON.stringify(items));
      actions.addRoute({
        path: `${context.baseUrl}search/`,
        component: '@site/src/components/DocsSearch.jsx',
        modules: {items: data},
        exact: true,
      });
    },
  };
};
