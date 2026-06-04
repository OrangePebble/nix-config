{
  pkgs,
  pkgs-stable,
  funcs,
  vars,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    # The GOAT.
    ffmpeg

    # A GUI music tagger.
    picard

    # Dependency for the ReplayGain 2.0 picard plugin.
    rsgain

    # Tool to mass download lrc lyrics for tracks.
    lrcget

    # A TUI music tagger.
    # Uses an overlay to import additional plugins.
    # WARN: Hopefully removing this from stable-pkgs works
    beets

    # A TUI music downloader from multiple sources.
    streamrip

    # Youtube and many other sources TUI downloader.
    yt-dlp

    # App to play background noise like rain and wind.
    blanket

    # Music player
    gapless

    # Subsonic/Navidrome client.
    supersonic
  ];

  hm.services.flatpak.packages = [
    # yt-dlp GUI frontend.
    "org.nickvision.tubeconverter"

    # App to play background music/noises from Animal Crossing.
    "camp.nook.nookdesktop"

    # Good looking widget that displays and controls the currently playing media.
    # Could be cool to use with something like a terminal music player.
    # But on KDE I could just use the included media player in the system tray.
    "dev.geopjr.Turntable"

    # Cool internet radio app.
    "de.haeckerfelix.Shortwave"
  ];

  # This is causing errors to show up :(
  # I need to use hm...initExtra so the command has autocompletion available.
  # hm.programs.bash.initExtra = ''
  #   eval "$(beet completion)"
  # '';

  environment.shellAliases = {
    # I couldn't figure out how to actually install this binary, so I just
    #  created an alias to it.
    # I tried making a derivation using the repo but it was missing libraries
    #  and I couldn't figure out how to solve it.
    streaming_extractor_music = "${funcs.mkMutableConfigSymlink ./essentia/streaming_extractor_music}";
  };

  # Docs: https://beets.readthedocs.io/en/stable/
  # Run `beet config -e` to edit this file.
  hm.home.file.".config/beets/config.yaml".source = funcs.mkMutableConfigSymlink ./beets.yaml;
  hm.home.file.".config/beets/languagerewrite.yaml".source =
    funcs.mkMutableConfigSymlink ./languagerewrite.yaml;
  hm.home.file.".config/beets/paths.yaml".text =
    let
      essentia_models = fetchTarball {
        url = "https://essentia.upf.edu/svm_models/essentia-extractor-svm_models-v2.1_beta5.tar.gz";
        sha256 = "sha256:11ps1l4h8bl4l9rlvkhjs61908l18dh7mpq65brm8ki99hnp9g64";
      };
      streaming_extractor_music = "${funcs.mkMutableConfigSymlink ./essentia/streaming_extractor_music}";
    in
    ''
      xtractor:
        essentia_extractor: ${streaming_extractor_music}
        extractor_profile:
          highlevel:
            svm_models:
              # https://acousticbrainz.org/datasets/accuracy
              # These have to be absolute links.
              - ${essentia_models}/danceability.history
              - ${essentia_models}/gender.history
              - ${essentia_models}/genre_rosamerica.history
              - ${essentia_models}/mood_acoustic.history
              - ${essentia_models}/mood_aggressive.history
              - ${essentia_models}/mood_electronic.history
              - ${essentia_models}/mood_happy.history
              - ${essentia_models}/mood_party.history
              - ${essentia_models}/mood_relaxed.history
              - ${essentia_models}/mood_sad.history
              - ${essentia_models}/moods_mirex.history
              - ${essentia_models}/voice_instrumental.history
              # The following aren't used by the plugin:
              # - ${essentia_models}/genre_dortmund.history
              # - ${essentia_models}/genre_electronic.history
              # - ${essentia_models}/genre_tzanetakis.history
              # - ${essentia_models}/ismir04_rhythm.history
              # - ${essentia_models}/timbre.history
              # - ${essentia_models}/tonal_atonal.history
    '';
  secrets.beets-secrets = {
    sopsFile = ./secrets.yaml;
    format = "yaml";
    key = ""; # Entire file.
    # Only the user and group can read and nothing else.
    mode = "0440";
    owner = vars.username;
  };
}
