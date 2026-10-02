{
  config,
  ...
}:
{
  hm = {
    # builtins.toJSON also converts lib.mkMerge and lib.mkIf to JSON, so not using it.
    # Although I'm not using lib.mkMerge and lib.mkIf because it is not counted as a string.
    # Using regular if/else doesn't check unused path but its just string so it doesn't matter.
    # But does it still not check the other if/else path if its called by a specialisation?

    # According to https://lemmy.zip/comment/20970220 the color profile has to be set for sleep to work properly.
    home.file.".config/kwinoutputconfig.json".text = ''
      [
          {
            "data": [
                {
                    "allowDdcCi": true,
                    "allowSdrSoftwareBrightness": true,
                    "autoRotation": "InTabletMode",
                    "brightness": 1,
                    "colorPowerTradeoff": "PreferAccuracy",
                    "colorProfileSource": "EDID",
                    "connectorName": "DP-1",
                    "detectedDdcCi": false,
                    "edidHash": "906fbcbfe0add5daca5f1b7377181b74",
                    "edidIdentifier": "BNQ 32647 21573 35 2023 0",
                    "edrPolicy": "always",
                    "highDynamicRange": false,
                    "iccProfilePath": "",
                    "maxBitsPerColor": 0,
                    "mode": {
                        "height": 1440,
                        "refreshRate": 165002,
                        "width": 2560
                    },
                    "overscan": 0,
                    "rgbRange": "Automatic",
                    "scale": 1,
                    "sdrBrightness": 200,
                    "sdrGamutWideness": 0,
                    "transform": "Normal",
                    "uuid": "74a2421c-f9cd-4b38-a238-a39eee103c2c",
                    "vrrPolicy": "Automatic",
                    "wideColorGamut": false
                },
                {
                    "allowDdcCi": true,
                    "allowSdrSoftwareBrightness": true,
                    "autoRotation": "InTabletMode",
                    "brightness": 0,
                    "colorPowerTradeoff": "PreferAccuracy",
                    "colorProfileSource": "EDID",
                    "connectorName": "DP-2",
                    "detectedDdcCi": false,
                    "edidHash": "f80358606f64febb2fe92081b9c37fea",
                    "edidIdentifier": "AOC 9616 9795 36 2018 0",
                    "edrPolicy": "always",
                    "highDynamicRange": false,
                    "iccProfilePath": "",
                    "maxBitsPerColor": 0,
                    "mode": {
                        "height": 1080,
                        "refreshRate": 144001,
                        "width": 1920
                    },
                    "overscan": 0,
                    "rgbRange": "Automatic",
                    "scale": 1,
                    "sdrBrightness": 200,
                    "sdrGamutWideness": 0,
                    "transform": "Normal",
                    "uuid": "00782bec-50c8-4835-85a2-f78dd85c707e",
                    "vrrPolicy": "Automatic",
                    "wideColorGamut": false
                }
            ],
              "name": "outputs"
          },
          {
              "data": [
                  {
                      "lidClosed": false,
                      "outputs": [
                          {
                              "enabled": true,
                              "outputIndex": 0,
                              "position": {
                                  "x": 0,
                                  "y": 0
                              },
                              "priority": 0
                          },
                          {
                              "enabled": ${
                                if (!config.opts.one-1920x1080-screen) then "true" else "false"
                              },
                              "outputIndex": 1,
                              "position": {
                                  "x": 2560,
                                  "y": 360
                              },
                              "priority": 1
                          }
                      ]
                  }
              ],
              "name": "setups"
          }
      ]'';
  };
}
