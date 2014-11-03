GPS Logger for iOS
==================

This app is an experiment at gathering data from the iPhone 5s with its new location and motion APIs. The app tracks:
* GPS location
* Motion State (walking, running, driving, stationary)
* Step count (in progress)

The app gathers data with no network connection and stores locally on disk. The data is sent to the server in a batch when the user chooses.


## API

The app will make a POST request to the configured endpoint that looks like the following:

```
{
  "locations": [
    {
      "timestamp": 1383355053,
      "latitude": 37.331800,
      "longitude": -122.030581,
      "altitude": 0,
      "speed": 4,
      "horizontal_accuracy": 30,
      "vertical_accuracy": -1,
      "motion": ["driving","stationary"]
    }
  ]
}
```


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




