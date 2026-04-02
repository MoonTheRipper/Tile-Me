const SiteConfiguration = {
  currentReleaseVersion: "1.0.3",
  repoUrl: "https://github.com/MoonTheRipper/Tile-Me",
  releasesUrl: "https://github.com/MoonTheRipper/Tile-Me/releases",
  latestReleaseApiUrl: "https://api.github.com/repos/MoonTheRipper/Tile-Me/releases/latest",
  themeStorageKey: "tileme.site.theme",
};

function normalizeSemanticVersion(rawVersion) {
  if (typeof rawVersion !== "string") {
    return null;
  }

  const match = rawVersion.trim().match(/^v?(\d+)\.(\d+)\.(\d+)$/);
  if (!match) {
    return null;
  }

  return {
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3]),
    label: `${match[1]}.${match[2]}.${match[3]}`,
  };
}

function resolveReleaseAsset(assets, extension) {
  return assets.find((asset) => {
    return typeof asset?.name === "string" &&
      typeof asset?.browser_download_url === "string" &&
      asset.name.toLowerCase().endsWith(extension);
  }) || null;
}

function getPreferredTheme() {
  try {
    const storedTheme = localStorage.getItem(SiteConfiguration.themeStorageKey);
    if (storedTheme === "light" || storedTheme === "dark") {
      return storedTheme;
    }
  } catch (error) {
    // Ignore storage failures and fall through to the system preference.
  }

  return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function applyTheme(theme) {
  const normalizedTheme = theme === "dark" ? "dark" : "light";
  document.documentElement.dataset.theme = normalizedTheme;

  const themeToggle = document.getElementById("theme-toggle");
  if (themeToggle) {
    const isDark = normalizedTheme === "dark";
    themeToggle.setAttribute("aria-pressed", String(isDark));
    themeToggle.setAttribute("aria-label", isDark ? "Switch to light mode" : "Switch to dark mode");

    const label = themeToggle.querySelector(".theme-toggle-label");
    if (label) {
      label.textContent = isDark ? "Dark mode" : "Light mode";
    }
  }

  try {
    localStorage.setItem(SiteConfiguration.themeStorageKey, normalizedTheme);
  } catch (error) {
    // Ignore storage failures silently.
  }
}

function updateDownloadUI({
  primaryUrl,
  primaryLabel,
  versionLabel,
  statusText,
  zipUrl = null,
  zipLabel = "Download ZIP",
}) {
  document.querySelectorAll("[data-download-link]").forEach((link) => {
    link.href = primaryUrl;
    link.textContent = primaryLabel;
  });

  const versionTargets = document.querySelectorAll("[data-latest-version]");
  versionTargets.forEach((node) => {
    node.textContent = versionLabel;
  });

  const heroVersionPill = document.getElementById("hero-version-pill");
  if (heroVersionPill) {
    heroVersionPill.textContent = versionLabel === "Latest"
      ? "Latest GitHub release"
      : `Latest release v${versionLabel}`;
  }

  const downloadVersion = document.getElementById("download-version");
  if (downloadVersion) {
    downloadVersion.textContent = versionLabel === "Latest"
      ? "Latest GitHub release"
      : `Version ${versionLabel}`;
  }

  const releaseStatus = document.getElementById("release-status");
  if (releaseStatus) {
    releaseStatus.textContent = statusText;
  }

  const releasesLink = document.getElementById("releases-link");
  if (releasesLink) {
    releasesLink.href = SiteConfiguration.releasesUrl;
  }

  const zipLink = document.getElementById("zip-download-link");
  if (zipLink) {
    if (zipUrl) {
      zipLink.hidden = false;
      zipLink.href = zipUrl;
      zipLink.textContent = zipLabel;
    } else {
      zipLink.hidden = true;
      zipLink.href = SiteConfiguration.releasesUrl;
      zipLink.textContent = "Download ZIP";
    }
  }
}

async function fetchLatestRelease() {
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), 7000);

  try {
    const response = await fetch(SiteConfiguration.latestReleaseApiUrl, {
      headers: {
        Accept: "application/vnd.github+json",
      },
      signal: controller.signal,
    });

    if (!response.ok) {
      throw new Error(`GitHub response ${response.status}`);
    }

    const release = await response.json();
    const version = normalizeSemanticVersion(release.tag_name || release.name || "");
    const assets = Array.isArray(release.assets) ? release.assets : [];
    const dmgAsset = resolveReleaseAsset(assets, ".dmg");
    const zipAsset = resolveReleaseAsset(assets, ".zip");
    const releasePageUrl = typeof release.html_url === "string" ? release.html_url : SiteConfiguration.releasesUrl;

    if (!version) {
      updateDownloadUI({
        primaryUrl: dmgAsset?.browser_download_url || zipAsset?.browser_download_url || releasePageUrl,
        primaryLabel: dmgAsset ? "Download latest DMG" : zipAsset ? "Download latest ZIP" : "Open latest release",
        versionLabel: "Latest",
        statusText: "The latest release is available, but its version label could not be parsed cleanly.",
        zipUrl: dmgAsset && zipAsset ? zipAsset.browser_download_url : null,
      });
      return;
    }

    updateDownloadUI({
      primaryUrl: dmgAsset?.browser_download_url || zipAsset?.browser_download_url || releasePageUrl,
      primaryLabel: dmgAsset ? `Download v${version.label} DMG` : zipAsset ? `Download v${version.label} ZIP` : `Open v${version.label} release`,
      versionLabel: version.label,
      statusText: dmgAsset
        ? `Version ${version.label} is ready to download as a DMG.`
        : zipAsset
          ? `Version ${version.label} is available as a ZIP.`
          : `Version ${version.label} is live on GitHub Releases.`,
      zipUrl: dmgAsset && zipAsset ? zipAsset.browser_download_url : null,
      zipLabel: version ? `Download v${version.label} ZIP` : "Download ZIP",
    });
  } catch (error) {
    updateDownloadUI({
      primaryUrl: `${SiteConfiguration.releasesUrl}/download/v${SiteConfiguration.currentReleaseVersion}/Tile-Me-v${SiteConfiguration.currentReleaseVersion}.dmg`,
      primaryLabel: `Download v${SiteConfiguration.currentReleaseVersion} DMG`,
      versionLabel: SiteConfiguration.currentReleaseVersion,
      statusText: `Version ${SiteConfiguration.currentReleaseVersion} is available as the current public build. Live GitHub release metadata is unavailable right now.`,
      zipUrl: `${SiteConfiguration.releasesUrl}/download/v${SiteConfiguration.currentReleaseVersion}/Tile-Me-v${SiteConfiguration.currentReleaseVersion}.zip`,
      zipLabel: `Download v${SiteConfiguration.currentReleaseVersion} ZIP`,
    });
  } finally {
    window.clearTimeout(timeout);
  }
}

function wireThemeToggle() {
  applyTheme(getPreferredTheme());

  const toggle = document.getElementById("theme-toggle");
  if (!toggle) {
    return;
  }

  toggle.addEventListener("click", () => {
    const nextTheme = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
    applyTheme(nextTheme);
  });
}

function setCurrentYear() {
  const yearNode = document.getElementById("current-year");
  if (yearNode) {
    yearNode.textContent = String(new Date().getFullYear());
  }
}

document.addEventListener("DOMContentLoaded", () => {
  wireThemeToggle();
  setCurrentYear();
  fetchLatestRelease();
});
