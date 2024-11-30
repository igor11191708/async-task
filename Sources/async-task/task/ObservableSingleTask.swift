//
//  ObservableSingleTask.swift
//  async-task
//
//  Created by Igor Shelopaev on 28.11.24.
//

import SwiftUI

extension Async {
    /// A view model for managing a cancellable asynchronous task in a SwiftUI environment.
    ///
    /// This class provides lifecycle management for a single asynchronous task, including cancellation,
    /// error handling, and state management. It integrates seamlessly with SwiftUI using `@Observable`
    /// to notify views about state changes.
    ///
    /// - Note: Exclusively operates on the main actor to ensure thread safety, making it suitable for
    ///         UI-related tasks in declarative SwiftUI workflows.
    @MainActor
    @Observable
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    public final class ObservableSingleTask<V: Sendable, E: Error>: IAsyncTask {
        
        // MARK: - Public Properties
        
        /// The error encountered during the task, if any.
        ///
        /// This property is updated when the task encounters an error. It may be set by the custom
        /// `errorMapper` or directly by the task itself.
        public private(set) var error: E?
        
        /// The result produced by the asynchronous task, if available.
        ///
        /// Holds the task's output upon successful completion. If the task fails or is cancelled,
        /// this property will remain `nil`.
        public private(set) var value: V?
        
        /// The current state of the task.
        ///
        /// Indicates whether the task is idle, active, or completed. This property is reactive
        /// and can be used to update the UI based on the task’s progress.
        public private(set) var state: Async.State = .idle
        
        /// A custom error handler for mapping generic errors to the specified error type `E`.
        ///
        /// This optional closure allows context-specific transformations of errors encountered
        /// during task execution.
        public let errorMapper: ErrorMapper<E>?
        
        // MARK: - Private Properties
        
        /// A reference to the currently running task.
        ///
        /// This property manages the lifecycle of the task, enabling cancellation and cleanup upon completion.
        private var task: Task<Void, Never>?
        
        // MARK: - Initialization
        
        /// Initializes a new instance of `ObservableSingleTask`.
        ///
        /// - Parameter errorMapper: A closure for custom error handling, allowing transformation of
        ///   errors into the specified error type `E`. Defaults to `nil`.
        public init(
            errorMapper: ErrorMapper<E>? = nil
        ) {
            self.errorMapper = errorMapper
        }
        
        // MARK: - Public Methods
                
        /// Cancels the currently running task, if any.
        ///
        /// Safely stops the task, clears its reference, and updates the state to `.idle`. If no task
        /// is running, calling this method has no effect.
        public func cancel() {
            if let task {
                task.cancel()
                self.task = nil
            }
            setState(.idle)
        }
        
        /// Manages the lifecycle of an asynchronous task.
        ///
        /// Centralizes task execution, state management, and error handling. Automatically transitions
        /// the task’s state upon completion or failure.
        ///
        /// - Parameters:
        ///   - priority: The priority of the task, influencing its execution order. Defaults to `nil`.
        ///   - operation: A closure that performs the asynchronous task and returns a value of type `V`.
        ///     The closure can throw an error if the task fails.
        public func startTask(
            priority: TaskPriority? = nil,
            _ operation: @escaping Producer<V>
        ) {
            cancel()
            clean()
            setState(.active)

            task = Task<Void, Never>(priority: priority) { [weak self] in
                defer {
                    self?.setState(.idle)
                    self?.task = nil
                }
                do {
                    self?.value = try await operation()
                } catch {
                    self?.error = self?.handle(error)
                }
            }
        }
       
        // MARK: - Private Methods
        
        /// Clears the specified properties of the asynchronous task.
        ///
        /// Allows selective clearing of task properties such as `error` or `value`. By default, it
        /// clears both the `error` and `value` properties unless specific properties are provided.
        ///
        /// - Parameter fields: An array of `TaskProperty` values specifying which properties to clear.
        ///   Defaults to `[.error, .value]`.
        private func clean(fields: [Async.TaskProperty] = [.error, .value]) {
            for field in fields {
                switch field {
                    case .error: resetError()
                    case .value: resetValue()
                }
            }
        }
        
        /// Resets the `error` property of the asynchronous task.
        ///
        /// Clears any error information stored in the task.
        private func resetError() {
            self.error = nil
        }

        /// Resets the `value` property of the asynchronous task.
        ///
        /// Clears any result produced by the task.
        private func resetValue() {
            self.value = nil
        }
        
        /// Updates the task’s state.
        ///
        /// - Parameter value: The new state to set for the task.
        private func setState(_ value: State) {
            state = value
        }
    }
}
