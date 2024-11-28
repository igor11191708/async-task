//
//  IAsyncTask.swift
//  async-task
//
//  Created by Igor on 28.11.24.
//

import Foundation

/// A protocol defining the behavior of an asynchronous task manager with cancellation and error handling capabilities.
///
/// This protocol abstracts the lifecycle management of a cancellable asynchronous task. It provides functionalities
/// such as state management, error handling, and task cancellation, making it easier to integrate asynchronous
/// operations into applications with a consistent and reusable interface.
///
/// - Note: This protocol is designed to work in environments where updates must occur on the main actor,
///         ensuring thread safety for UI-related operations.
@MainActor
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public protocol IAsyncTask: AnyObject {
    
    /// The type of the value produced by the asynchronous task.
    associatedtype Value: Sendable
    
    /// The type of the error that may occur during the asynchronous task's execution.
    associatedtype ErrorType: Error, Sendable

    // MARK: - Properties

    /// The error encountered during the task, if any.
    ///
    /// This property is updated whenever an error occurs during task execution.
    var error: ErrorType? { get }

    /// The result produced by the asynchronous task, if available.
    ///
    /// This property holds the value produced by a successfully completed task.
    var value: Value? { get }

    /// The current state of the task.
    ///
    /// Indicates whether the task is idle, active, or completed.
    var state: Async.State { get }
    
    /// A custom error mapper used to process and transform errors encountered during task execution.
    ///
    /// This closure allows custom error handling and mapping of generic errors into the specified `ErrorType`.
    var errorMapper: Async.ErrorMapper<ErrorType>? { get }

    // MARK: - Methods

    /// Clears the current value and error state.
    ///
    /// Use this method to reset the task's state before starting a new task or after handling the current results.
    func clean()

    /// Cancels the currently running task, if any.
    ///
    /// This method stops the task, resets the task reference, and updates the state to `.idle`.
    func cancel()

    /// Starts an asynchronous operation without requiring input.
    ///
    /// This method initializes an asynchronous task using the provided closure. It resets the current state,
    /// starts the task, and handles its lifecycle, including error management and state updates.
    ///
    /// - Parameter operation: A closure that performs an asynchronous task and returns
    ///   a value of type `Value` upon completion. The closure can throw an error if the task fails.
    func start(operation: @escaping Async.Producer<Value>)

    /// Starts an asynchronous operation with a specified input.
    ///
    /// This method initializes an asynchronous task using the provided closure and input value.
    /// The input can be of any type conforming to `Sendable`, ensuring thread safety for concurrent operations.
    ///
    /// - Parameters:
    ///   - input: A value of type `I` to be passed to the `operation` closure.
    ///   - operation: A closure that takes an input of type `I`, performs an asynchronous task, and
    ///     returns a value of type `Value` upon completion. The closure can throw an error if the task fails.
    func start<I: Sendable>(with input: I, operation: @escaping Async.Mapper<I, Value>)
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension IAsyncTask {
    
    /// Processes and maps errors encountered during task execution.
    ///
    /// This method uses the custom error mapper to transform errors into the expected type `ErrorType`.
    /// If no custom mapper is provided, it attempts to cast the error directly to `ErrorType`.
    /// If the error cannot be mapped or cast, the error state is cleared.
    ///
    /// - Parameter error: The error encountered during task execution.
    /// - Returns: A mapped or cast error of type `ErrorType`, or `nil` if the error could not be processed.
    @MainActor
    public func handle(_ error: Error) -> ErrorType? {
        if let error = errorMapper?(error) {
            return error
        } else if let error = error as? ErrorType {
            return error
        }
        
        return nil
    }
}