//
//  Modifiers.swift
//  NetMock
//
//  Created by Christopher Wainwright on 14/10/2025.
//


/// Parser Modifiers
extension Parser {
    /// Make Compound Parser Atomic
    /// 
    /// Make parser groupings atomic, either they complete completely,
    /// or fail and restore the partially consumed string to its original state.
    /// - Returns: The calling parser with atomicity applied to its run operation.
    func atomic() -> Parser<T> {
        .init { input in
            let original = input
            do {
                return try self.run(&input)
            } catch {
                input = original
                throw error
            }
        }
    }
    
    /// Make Parser Optional
    /// 
    /// This modifier transforms the output of the parser to an optional.
    /// - If the parser completes successfully, it will return the value as normal.
    /// - If the parser does not complete, it will return nil and restore the input to its original.
    /// - Returns: The calling parser with optionality built into its run operation.
    func optional() -> Parser<T?> {
        .init { input in
            let original = input
            if let result = try? self.run(&input) {
                return result
            }
            input = original
            return nil
        }
    }
    
    /// Make Parser Optional
    /// 
    /// This modifier adds a default to the parser output.
    /// - If the parser completes successfully, it will return its result as normal.
    /// - If the parser does not complete, it will return a default value and restore the input to its original.
    /// - Parameter defaultValue: A default value to return in case the parser fails.
    /// - Returns: The calling parser with optionality built into its run operation.
    func optional(defaultValue: T) -> Parser<T> {
        .init { input in
            try self.optional().run(&input) ?? defaultValue
        }
    }
    
    /// Discard Parser's Output
    ///
    /// Useful when you want to consume a token without using the result
    func discard() -> Parser<Void> {
        .init { input in
            let _ = try? self.run(&input)
        }
    }
    
    /// Consume Multiple Tokens Sequentially
    ///
    /// - Parameters:
    ///   - separator: customise the separator between each element in your sequence, defaults to ', ' (with optional trailing whitespace).
    ///   - allowEmpty: accept no instances of elements and separators, returning an empty array.
    ///   - allowTrailingSeparator: accept a single trailing separator in list.
    /// - Returns: A sequence parser which will greedily parse as many elements from its calling parser with a configured separator.
    func sequence<U>(separator: Parser<U> = (.character(",") *> .whitespace().optional()), allowEmpty: Bool = true, allowTrailingSeparator: Bool = true) -> Parser<[T]> {
        .init { input in
            var results: [T] = []
            
            do {
                let first = try self.run(&input)
                results.append(first)
            } catch {
                if allowEmpty {
                    return results
                } else {
                    throw error
                }
            }
            
            while !input.isEmpty {
                let original = input
                do {
                    let _ = try separator.run(&input)
                    do {
                        let element = try self.run(&input)
                        results.append(element)
                    } catch {
                        if allowTrailingSeparator {
                            return results
                        } else {
                            throw error
                        }
                    }
                } catch {
                    input = original
                    return results
                }
            }
            
            return results
        }
    }
    
    /// Provide Context for Thrown Errors
    /// 
    /// When an error is thrown by a parser, this modifier will catch the error,
    /// wrapping it with a `String` to provide additional context as to where the error was thrown.
    /// - Parameter label: A descriptive label to add context to an error.
    /// - Returns: The calling parser with context attached to its error case.
    func context(_ label: String) -> Parser<T> {
        .init { input in
            do {
                return try self.run(&input)
            } catch {
                if let parseError = error as? ParseError {
                    throw ParseError.contextualError(label, parseError)
                } else {
                    throw error
                }
            }
        }
    }
    
    /// Require all input of a parse to be consumed
    ///
    /// Trailing input which remains unconsumed will trigger an .incompleteParser error
    /// - Returns: Return the calling parser with a requirement to completely consume the input.
    func complete() -> Parser<T> {
        .init { input in
            do {
                let result = try self.run(&input)
                
                if !input.isEmpty {
                    throw ParseError.incompleteParse(input)
                }
                
                return result
            }
        }
    }
    
    /// Extract first error (if available)
    ///
    /// Extract first error from an `.eitherError`.
    /// - Returns: In the case of an `.eitherError` being thrown, throw its `firstError`, otherwise just catch and re-throw the error.
    func firstError() -> Parser<T> {
        .init { input in
            do {
                return try self.run(&input)
            } catch let parseError as ParseError {
                switch parseError {
                case .eitherError(let firstError, _) : throw firstError
                default: throw parseError
                }
            }
        }
    }
    
    /// Extract second error (if available)
    ///
    /// Extract second error from an `.eitherError`.
    /// - Returns: In the case of an `.eitherError` being thrown, throw its `secondError`, otherwise just catch and re-throw the error.
    func secondError() -> Parser<T> {
        .init { input in
            do {
                return try self.run(&input)
            } catch let parseError as ParseError {
                switch parseError {
                case .eitherError(_, let secondError) : throw secondError
                default: throw parseError
                }
            }
        }
    }
}
