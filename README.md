Overland GPS Tracker for iOS
============================

https://overland.p3k.app

This app tracks your location in the background and sends the data to a server of your choosing. The app tracks:

* GPS location
* Motion State (walking, running, driving, cycling, stationary)
* Steps
* Battery level

The app gathers data even when the phone is offline, and the data is sent to the server in a batch at an interval set by the user.

There are many settings available in the settings tab which allow you to adjust properties of the CoreLocation API.

The app sends data to an HTTP endpoint. You can use [an existing server](https://overland.p3k.app/servers) or build your own.

Looking for an Android version? → https://overland.p3k.app/servers#apps

## Documentation

The documentation is on the website:

* [Guide](https://overland.p3k.app/guide) - the Tracker screen, trips and trip modes, the Live Activity, Shortcuts and Siri, widgets, controls and Apple Health
* [Settings](https://overland.p3k.app/settings) - every setting, trip settings, and recommended setups for detail or battery life
* [Servers and apps](https://overland.p3k.app/servers) - servers that work with Overland, and other apps that send data the same way
* [API](https://overland.p3k.app/api) - what the app sends to your server, how to reply, and how your server can configure the app
* [Saving to iCloud Drive](https://overland.p3k.app/icloud)
* [Home Assistant](https://overland.p3k.app/home-assistant)

### Settings

See [Settings](https://overland.p3k.app/settings) on the website.

## API

See [API](https://overland.p3k.app/api) on the website.

### Trip Records

See [Trip records](https://overland.p3k.app/api#trip-records) on the website.

### Response

See [Response](https://overland.p3k.app/api#response) on the website.

#### Configuration by Server Response

See [Configuration by server response](https://overland.p3k.app/api#configuration-by-server-response) on the website.

## Home Assistant Integration

See [Home Assistant](https://overland.p3k.app/home-assistant) on the website.

## Development Setup

This assumes you have [Xcode](https://developer.apple.com/xcode/) and [Homebrew](https://brew.sh) installed. A paid Apple Developer account is not needed.

* `git clone https://github.com/aaronpk/Overland-iOS.git && cd Overland-iOS`
* `brew install cocoapods`
* `pod install`
* `open Overland.xcworkspace`
* In Project Navigator, select *Overland*, and update Project Settings:
    * Identity → Bundle Identifier: *com.yourname.overland*
    * Signing → Team: *Personal Team*
* Plug in your iOS device
* Product → Destination -> select your device
* Product → Run (⌘R)
* On your iOS device: Settings -> General -> Device Management -> Developer App -> Trust
* You can now launch the Overland app on your iOS device


## License

Contributions from 2017 onward are copyright by Aaron Parecki and contributors

Contributions from 2013-2016 are copyright by Esri, Inc.

The built-in trip mode icons are made from [Material Symbols](https://github.com/google/material-design-icons) by Google, also licensed under the Apache License, Version 2.0.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.




