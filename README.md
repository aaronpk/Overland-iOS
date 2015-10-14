GPS Logger for iOS
==================

This app is an experiment at gathering data from an iPhone to test the Core Location API and its various settings. The app tracks:
* GPS location
* Motion State (walking, running, driving, cycling, stationary)
* Battery level

The app gathers data with no network connection and stores locally on disk. The data is sent to the server in a batch at an interval set by the user.


## API

The app will post the location data to the configured endpoint. The POST request will be an array of GeoJSON objects inside a property called "locations". This may look like the following:

```
{
  "locations": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": {
          "latitude": 37.331800,
          "longitude": -122.030581
        }
      },
      "properties": {
        "timestamp": "2015-10-01T08:00:00-0700",
        "altitude": 0,
        "speed": 4,
        "horizontal_accuracy": 30,
        "vertical_accuracy": -1,
        "motion": ["driving","stationary"],
        "pauses": false,
        "activity": "other_navigation",
        "desired_accuracy": 100,
        "deferred": 1000,
        "significant_change": "disabled",
        "locations_in_payload": 1,
        "battery_state": "charging",
        "battery_level": 0.89
      }
    }
  ]
}
```

The properties on the location object are as follows:

* `timestamp` - the ISO8601 timestamp of the `CLLocation` object recorded
* `altitude` - the altitude of the location in meters
* `speed` - meters per second
* `horizontal_accuracy` - accuracy of the position in meters
* `vertical_accuracy` - accuracy of the altitude in meters
* `motion` - an array of motion states detected by the motion coprocessor. Possible values are: `driving`, `walking`, `running`, `cycling`, `stationary`. A common combination is `driving` and `stationary` when the phone is resting on the dashboard of a moving car.
* `pauses` - boolean, whether the "pause updates automatically" preference is checked
* `activity` - a string denoting the type of activity as indicated by the setting. Possible values are `automotive_navigation`, `fitness`, `other_navigation` and `other`. This can be set on the settings screen.
* `desired_accuracy` - the requested accuracy in meters as configured on the settings screen.
* `deferred` - the distance in meters to defer location updates, configured on the settings screen.
* `significant_change` - a string indicating the significant change mode, `disabled`, `enabled` or `exclusive`.
* `locations_in_payload` - the number of locations that were sent in the batch along with this location
* `battery_state` - `unknown`, `charging`, `full`, `unplugged`
* `battery_level` - a value from 0 to 1 indicating the percent battery remaining.


## Contributing

Esri welcomes contributions from anyone and everyone. Please see our [guidelines for contributing](https://github.com/esri/contributing).


## License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.




