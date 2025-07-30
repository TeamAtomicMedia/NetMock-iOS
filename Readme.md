# NetMock

## Setup

NetMock is a tool to swap in mock responses for API calls, for use in offline app configurations and unit/UI tests.
NetMock will inject the mock responses, where defined via nm files, and fall back to live API calls where a NetMock file can't be found.

To make use of NetMock, add NetMockURLProtocol to your URLSessionConfiguration when constructing a URLSession:
```swift
let configuration = URLSessionConfiguration.ephemeral
configuration.protocolClasses = [NetMockURLProtocol.self]
return URLSession(configuration: configuration)
```

And make sure you initialise NetMock:
```swift
NetMock.shared.initialise()
NetMock.shared.initialise(bundle: .module) // If using in a package
```

You may then add NetMock files to your offline app target, or unit test target, and they will be included in the Bundle and detected by NetMock.

## NetMock files

NetMock files contain mock responses, and can be used to avoid making live calls, allowing us to develop or test an app offline using real, saved API responses. NetMock will find all these files, and inject them as responses when a request is made.

### Format

A typical NetMock response file looks as follows:

`ExampleGETAPI.nm`
```
GET https://api.example.com/example

200
{
  "jsonValue": 123
}
```

### Providing alternative status codes

You may provide alternative responses for different status codes:

`ExampleGETAPI.nm`
```
GET https://api.example.com/example

200
{
  "jsonValue": 123
}
---
404
---
418
{
  "example": "abc"
}
---
500
```

### Response sequences

The first response will be used by default, but a response or sequence of responses can be configured:

`ExampleGETAPI.nm`
```
GET https://api.example.com/example 200 500 200

200
{
  "jsonValue": 123
}
---
404
---
418
{
  "example": "abc"
}
---
500
```

In this example, 200 will be used for the first call, then 500, then 200 will be used for all subsequent calls.

### Response disambiguation

To disambiguate, responses can be named:

`ExampleGETAPI.nm`
```
GET https://api.example.com/example Success 500 SuccessLong

200 Success
{
  "jsonValue": 123
}
---
200 SuccessLong
{
  "jsonValue": 123,
  "anotherJSONValue": 456
}
---
404
---
418
{
  "example": "abc"
}
---
500
```

## Testing & Overrides

In unit tests, overrides can be provided using the NetMock API:
```swift
NetMock.override("https://api.example.com/example", responses: ["Success", "500", "404", "SuccessLong"])
```

In UI tests, the UI test target could communicate to the app via launch arguments to build an API like so:
```swift
AppRobot()
    .netmockOverride("https://api.example.com/example", responses: "Success", "500", "404", "SuccessLong")
```

## Live responses

Specifying an identifier of "#Live" will tell the test to perform the real API call. Sequencing #Live is not supported.
