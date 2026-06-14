{
  pkgs,
  inputs,
  funcs,
  vars,
  ...
}:
{
  hm = {
    imports = [
      inputs.zen-browser.homeModules.beta
    ];

    # Makes bookmarks look like essentials.
    home.file.".config/zen/default/chrome/userChrome.css".source =
      funcs.mkMutableConfigSymlink ./userChrome.css;

    programs.zen-browser = {
      enable = true;

      # Check the following for options:
      #  about:policies#documentation
      #  https://mozilla.github.io/policy-templates
      policies = {
        DisableAppUpdate = true;
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        # https://mozilla.github.io/policy-templates/#enabletrackingprotection
        EnableTrackingProtection = {
          # Setting this false for a bit while I try AdNauseam.
          Value = false;
          #Value = true;

          Locked = false;
          Cryptomining = true;
          Fingerprinting = true;
          EmailTracking = true;
          SuspectedFingerprinting = true;
          BaselineExceptions = true;
          ConvenienceExceptions = false;
        };
        DisablePocket = true;
        DontCheckDefaultBrowser = true;
        DisplayBookmarksToolbar = "never"; # "never" "always" "newtab"
        DisplayMenuBar = "default-off"; # "default-off" "always" "never" "default-on"
        SearchBar = "unified"; # "unified" "separate"
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
        PasswordManagerEnabled = false;
        AutofillAddressEnabled = false;
        AutofillCreditCardEnabled = false;
        HttpsOnlyMode = true;

        # Disable welcome and update pages.
        OverrideFirstRunPage = "";
        OverridePostUpdatePage = "";
      };
      profiles.default = {
        settings = {
          # Makes extensions store things in IndexedDB instead of in files.
          # Extensions that aren't synced between devices store their settings here.
          # IndexedDB supposedly improves performance but doesn't allow me to
          #  declaratively set extension settings.
          # But I don't feel like declaring the settings for the few extensions that
          #  aren't synced, and the performance hit might not be worth it.
          "extensions.webextensions.ExtensionStorageIDB.enabled" = true;

          # Adds headers to my requests. It's up to the website whether they
          #  feel like following them.
          "privacy.globalprivacycontrol.enabled" = true;
          # This one no longer works.
          # "privacy.donottrackheader.enabled" = true;

          # Don't close the full browser when closing the last tab.
          "browser.tabs.closeWindowWithLastTab" = false;

          # Show this number of results for the url bar.
          # In Zen Browser you have to scroll to see all results.
          "browser.urlbar.maxRichResults" = 15;
          # Show search suggestions above known websites in the url bar.
          "browser.urlbar.showSearchSuggestionsFirst" = true;
          # Hide sponsored websites in the new tab page. More relevant for Firefox.
          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          # Same default search engine for both general and private browsing.
          "browser.search.separatePrivateDefault" = false;
          # Removes "Search with Google" from search results.
          "browser.newtabpage.pinned" = [ ];
          # Hide the bookmark toolbar.
          "browser.toolbars.bookmarks.visibility" = "never";
          # Load bookmarks in new tabs.
          "browser.tabs.loadBookmarksInTabs" = true;
          # Open searches and urls from the url bar in new tabs.
          "browser.urlbar.openintab" = true;

          # https://docs.zen-browser.app/guides/live-editing
          # Required to see the devtools for the browser UI and for userChrome.css to work.
          "devtools.debugger.remote-enabled" = true;
          "devtools.chrome.enabled" = true;
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

          # Use the system file picker.
          "widget.use-xdg-desktop-portal.file-picker" = 1;
          "widget.use-xdg-desktop-portal.mime-handler" = 1;

          # Hides the new tab button.
          "zen.tabs.show-newtab-vertical" = false;
          # Always floats the url bar when focused.
          "zen.urlbar.behavior" = "float";
          # Change focused split tab by hovering over it.
          "zen.splitView.change-on-hover" = true;
          # The first blue option.
          "zen.theme.accent-color" = "#aac7ff";
          # Set this to false to go back to regular Firefox new tab.
          "zen.urlbar.replace-newtab" = true;
          # Don't unload tabs after a while.
          "zen.tab-unloader.enabled" = false;
          # Show Firefox's protections icon in the url bar.
          "zen.urlbar.show-protections-icon" = true;
          # Hide the copy url button in the url bar.
          "zen.urlbar.single-toolbar-show-copy-url" = false;
          # Bring back the Firefox extensions button.
          "zen.theme.hide-unified-extensions-button" = false;

          "browser.uiCustomization.state" = builtins.toJSON {
            placements = {
              widget-overflow-fixed-list = [
              ];
              nav-bar = [
                "back-button"
                "stop-reload-button"
                "forward-button"
                "urlbar-container"
                "unified-extensions-button"
              ];
              toolbar-menubar = [
                # No idea what this does.
                "menubar-items"
              ];
              TabsToolbar = [
                "personal-bookmarks"
                "tabbrowser-tabs"
              ];
              vertical-tabs = [ ];
              PersonalToolbar = [ ];
              zen-sidebar-top-buttons = [
                "_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action" # Bitwarden
                "keepassxc-browser_keepassxc_org-browser-action" # KeePassXC-Browser
              ];
              zen-sidebar-foot-buttons = [
                "zen-toggle-compact-mode"
                # "preferences-button"
                "zen-workspaces-button"
                "downloads-button"
                "sidebar-button"
              ];
              # Some extensions may appear in the nav-bar if they're not here.
              # The extensions appear in this order.
              unified-extensions-area = [
                "addon_darkreader_org-browser-action" # Dark Reader
                "addon_karakeep_app-browser-action" # Karakeep
                "_531906d3-e22f-4a6c-a102-8057b88a1a63_-browser-action" # SingleFile
                "_d07ccf11-c0cd-4938-a265-2a4d6ad01189_-browser-action" # Web Archives
                "_aecec67f-0d10-4fa7-b7c7-609a2db280cf_-browser-action" # Violentmonkey
                # "_7a7a4a92-a2a0-41d1-9fd7-1e92480d612d_-browser-action" # Stylus
                "ublock0_raymondhill_net-browser-action" # uBlock Origin
                # "adnauseam_rednoise_org-browser-action" # AdNauseam
                "gdpr_cavi_au_dk-browser-action" # Consent-O-Matic
                "dearrow_ajay_app-browser-action" # DeArrow
                "sponsorblocker_ajay_app-browser-action" # SponsorBlock
                "enhancerforyoutube_maximerf_addons_mozilla_org-browser-action" # Enhancer for Youtube
                "_762f9885-5a13-4abd-9c77-433dcd38b8fd_-browser-action" # Return Youtube Dislike
                "_59c55aed-bdb3-4f2f-b81d-27011a689be6_-browser-action" # YouTube Windowed FullScreen
                "_a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad_-browser-action" # Refined GitHub
                "_036a55b4-5e72-4d05-a06c-cba2dfcc134a_-browser-action" # TWP - Translate Web Pages
                "default-bookmark-folder_gustiaux_com-browser-action" # Default Bookmark Folder
                # "amptra_keepa_com-browser-action" # Keepa
                # "_12cf650b-1822-40aa-bff0-996df6948878_-browser-action" # cookies.txt

                # Not sure it works with SearxNG, but I even forgot about it
                #  when using DuckDuckGo.
                # "_5d554479-7cc4-487f-bd25-d8fc67a42602_-browser-action" # FMHY SafeGuard
              ];
            };
            seen = [ ];
            dirtyAreaCache = [ ];
            # This has to be bigger than the "currentVersion" in about:config or prefs.js.
            "currentVersion" = 999;
            "newElementCount" = 0;
          };
        };
        # Tne flake has more info on how to install extensions.
        # https://github.com/0xc000022070/zen-browser-flake
        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          keepassxc-browser
          ublock-origin
          darkreader
          # The rest can just be installed by logging into the Firefox account.
        ];
        search = {
          force = true;
          default = "ddg";
          order = [
            "ddg"
            "google"
          ];
          # https://searchfox.org/firefox-main/rev/b7497e2adf09e8b17bf161df07945f42c9f8cfe5/toolkit/components/search/SearchEngine.sys.mjs#890-923
          engines = {
            "Nix Packages" = {
              urls = [ { template = "https://search.nixos.org/packages?channel=unstable&query={searchTerms}"; } ];
              updateInterval = 24 * 60 * 60 * 1000; # every day
              icon = "https://search.nixos.org/favicon-96x96.png";
              definedAliases = [ "@np" ];
            };
            "NixOS Options" = {
              urls = [ { template = "https://search.nixos.org/options?channel=unstable&query={searchTerms}"; } ];
              updateInterval = 24 * 60 * 60 * 1000; # every day
              icon = "https://search.nixos.org/favicon-96x96.png";
              definedAliases = [ "@no" ];
            };
            "NixOS Wiki" = {
              urls = [ { template = "https://wiki.nixos.org/w/index.php?search={searchTerms}"; } ];
              icon = "https://wiki.nixos.org/favicon.ico";
              updateInterval = 24 * 60 * 60 * 1000; # every day
              definedAliases = [ "@nw" ];
            };
            # Builtin engines only support specifying one additional alias.
            "google".metaData.alias = "@g";
            "perplexity".metaData.alias = "@p";
            # DDG uses bing so no point in having it as well.
            "bing".metaData.hidden = true;
          };
        };
      };
    };
  };
}
