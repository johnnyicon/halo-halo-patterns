# Install into a consuming repository

1) Add as submodule:
git submodule add <CATALOG_REPO_URL> .patterns/catalog

2) Copy templates:
node .patterns/catalog/scripts/install-to-consuming-repo.mjs --target .
