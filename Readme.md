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

The first response in the list will be used by default.

### Response sequences

The first response will be used by default, but a different default, or a sequence of responses can be configured. The last item in the sequence will be repeated if subsequent calls are made.

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

To disambiguate when multiple responses share a status code, responses can be named:

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

NetMock supports adding multiple names for a single response, separated by spaces, which could be useful when performing a naming migration, or when two use-cases happen to match.

### Live responses

Specifying an identifier of "#Live" will tell the test to perform the real API call. Sequencing calls after #Live is not supported, #Live must always be positioned at the end of the sequence.

`ExampleGETAPI.nm`
```
GET https://api.example.com/example 200 #Live

200
{
}
```

### Network availability errors / URLError

Networking errors occur when the server could not be reached, meaning no HTTP status code is available or relevant. These could include no internet, transport security failures, timeouts, and more.

To simulate a networking error, such as `URLError(.notConnectedToInternet)`, provide the corresponding error code in the response sequence:

`ExampleGETAPI.nm`
```
GET https://api.example.com/example -1009
```

By design, all URLError error codes are negative, while HTTP response codes are positive, so this is not ambiguous. Response body definitions for negative status codes will be ignored.

### Versioning

As of version 2.1.1, the NetMock file format support versioning, to make them forward-compatible with breaking changes to the file schema. This is achieved through an optional versioning header:

`ExampleGETAPI.nm`
```
NetMock 2.1.1
GET https://api.example.com/example
```

Breaking changes to the file format should generally be accompanied by a major version bump to the package, so in theory the major version specified by a file should be all that matters if we make use of this in future. However, minor versions are still parsed.

## Further configuration

### Custom URL handling

Many projects have a primary API which the apps calls, such as `https://api.example.com/`. In these cases, it may be desirable to maintain a single source of truth for this base URL, and specify only the API path in NetMock files.

NetMock allows a custom URL interpretation step to be inserted before its own parsing, allowing an app to specify its own schema for URLs. In the simple case, an app could check if the URL string is a full `https://` URL, and inject the API URL if not.

```swift
NetMock.shared.applyCustomURLParsing { urlString in
    if !urlString.hasPrefix("https://") {
        return URL(string: "https://api.example.com/" + urlString) // Example use-case: Inject API domain to API path specified in NetMock file
    }
    return nil // Use NetMock default behaviour, or previously set custom parsing
}
```

With this setup, we can simplify our call to `https://api.example.com/example`:

`ExampleGETAPI.nm`
```
GET example

200
```

### Testing & Overrides

In unit tests, overrides can be provided using the NetMock API:
```swift
NetMock.override("https://api.example.com/example", responses: ["Success", "500", "404", "SuccessLong"])
```

In UI tests, the UI test target could communicate to the app via launch arguments to build an API like so:
```swift
AppRobot()
    .netmockOverride("https://api.example.com/example", responses: "Success", "500", "404", "SuccessLong")
```

Note that consecutively run UI tests may preserve launch arguments, so the API used should account for this in resetting launch arguments even when no overrides are specified.

## Justification of approach

NetMock performs injection client-side, for a number of reasons:

- We can inject responses we want, and sequence them as needed, which we can't making actual requests to a live API.
- We can simulate a range of API error responses, which a mock API may not support.
- We can simulate network availability errors, which is just not possible via a mock API.
- We can make use of JSON responses captured during implementation & testing, with no code needed, which saves time compared to constructing responses programmatically.
- We can inject responses for calls to domains outside of our control without the need for a self-hosted DNS, and without the need to mimic transport security protections, providing an advantage to our scope of coverage compared to a localhost server.
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
