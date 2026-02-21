import Foundation
import Combine

protocol MissionZebraRepository {
    func getChildren() -> AnyPublisher<[Child], Never>
    func getTasks() -> AnyPublisher<[MZTask], Never>
    func getRewards() -> AnyPublisher<[Reward], Never>
    func completeTask(taskId: String, childId: String) async
}
