import Foundation

internal extension TaskGroup {
    
    private struct IndexedResult<Result> {
        let index: Int
        let value: Result
    }
    
    static func load<IDs: Sequence>(
        _ ids: IDs,
        task: @escaping (IDs.Element) async throws -> ChildTaskResult
    ) async throws -> [ChildTaskResult] {
        try await withThrowingTaskGroup(of: IndexedResult<ChildTaskResult>.self) { group in
            for (index, id) in ids.enumerated() {
                group.addTask {
                    .init(index: index, value: try await task(id))
                }
            }
            
            var results = [IndexedResult<ChildTaskResult>]()
            for try await result in group {
                results.append(result)
            }
            
            return results
                .sorted(by: { $0.index < $1.index })
                .map { $0.value }
        }
    }
}
