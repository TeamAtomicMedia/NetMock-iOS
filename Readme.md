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


### Live responses

Specifying an identifier of "#Live" will tell the test to perform the real API call. Sequencing calls after #Live is not supported.

`ExampleGETAPI.nm`
```
GET https://api.example.com/example 200 #Live
200
{
}
```

### URLError

To simulate a networking error, such as `URLError(.notConnectedToInternet)`, provide the corresponding error code in the response sequence:
`ExampleGETAPI.nm`
```
GET https://api.example.com/example -1009
```
All URLError error codes are negative, while HTTP response codes are positive, so this is not ambiguous. Response body definitions for negative status codes will be ignored.

### Versioning

As of version 2.1.1, NetMock has forward-compatibility for breaking changes, through an optional versioning header:
`ExampleGETAPI.nm`
```
NetMock 2.1.1
GET https://api.example.com/example
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

## Justification of approach

NetMock performs injection client-side, for a number of reasons:

- We can inject responses we want, and sequence as needed, which we can't making actual requests to a live API.
- We can make use of JSON responses captured during implementation & testing, with no code needed, which saves time compared to constructing responses programmatically.
- We can inject responses for domains outside of our control without the need for a self-hosted DNS, and without the need to mimic transport security protections, providing an advantage to our scope of coverage compared to an localhost server.
- NetMock achieves a lot of capability with very little actual implementation code, making it extremely maintainable to anyone with a little iOS experience, while other approaches could get significantly more complex.

### Injection

We can use NetMock for system calls and webviews:
```swift
URLProtocol.registerClass(NetMockURLProtocol.self)
```

We can use NetMock for any calls where we have access to the URLSession:
```swift
var urlSessionConfig = URLSessionConfiguration.ephemeral
urlSessionConfig.protocolClasses = [NetMockURLProtocol.self]
let urlSession = URLSession(configuration: urlSessionConfig)
```

If we don't have access to the URLSession point of construction, our options are more limited. If we have a Local configuration, it is still technically possible to change out the default globally in this configuration using swizzling, if we so desire:
```swift
#if LOCAL
private extension URLSessionConfiguration {
    @objc class var defaultWithNetMock: URLSessionConfiguration {
        let config = URLSessionConfiguration.defaultWithNetMock // Now has .default's implementation
        config.protocolClasses = [NetMockURLProtocol.self] + (config.protocolClasses ?? [])
        return config
    }
    static func swizzleDefault() {
        let original = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: defaultWithNetMock))!
        let replacement = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: `default`))!
        method_exchangeImplementations(original, replacement)
    }
}
#endif
```
