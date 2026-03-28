# Tile Me Website

The public Tile Me landing page lives in `docs/` so it can be published directly with GitHub Pages.

## Publish With GitHub Pages

1. Push the repository to GitHub.
2. In the repository settings, open `Pages`.
3. Set the source to `Deploy from a branch`.
4. Choose the main branch and the `/docs` folder.

## Update The Site

- Edit page content in [index.html](/Users/odunga/Desktop/TileMe/Tile-Me/docs/index.html).
- Edit styling in [site.css](/Users/odunga/Desktop/TileMe/Tile-Me/docs/assets/site.css).
- Edit latest-release download logic and theme behavior in [site.js](/Users/odunga/Desktop/TileMe/Tile-Me/docs/assets/site.js).

## Latest Download Resolution

The main download button uses the GitHub Releases API:

- it requests the latest release metadata for `moontheripper/Tile-Me`
- it prefers a `.dmg` asset
- it falls back to `.zip`
- if neither asset can be resolved, it falls back to the GitHub releases page

If the GitHub API is unavailable, the page stays usable and the main button still points to the releases page.
