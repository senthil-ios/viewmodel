//
//  ViewModel.swift
//  ViewModel
//
//  Created by Senthil on 07/09/26.
//

import Combine
import Foundation
import SwiftUI

// MARK: - Model

public struct Post: Codable, Sendable {

    public let userID: Int
    public let id: Int
    public let title: String
    public let body: String

    public init(
        userID: Int,
        id: Int,
        title: String,
        body: String
    ) {
        self.userID = userID
        self.id = id
        self.title = title
        self.body = body
    }

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case id
        case title
        case body
    }
}

// MARK: - Service Protocol

public protocol PostProtocol: Sendable {
    func getPost() async throws -> [Post]
}

// MARK: - Service

public actor PostService: PostProtocol {

    public init() {}

    public func getPost() async throws -> [Post] {

        guard let url = URL(
            string: "https://jsonplaceholder.typicode.com/posts"
        ) else {
            return []
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        let posts = try JSONDecoder().decode(
            [Post].self,
            from: data
        )

        return posts
    }
}

// MARK: - ViewModel

@MainActor
public final class ViewModel: ObservableObject {

    @Published public private(set) var isLoading = false
    @Published public private(set) var error = ""
    @Published public var query = ""
    @Published public private(set) var filteredPosts: [Post] = []

    private let service: PostService

    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    public init(service: PostService) {

        self.service = service

        $query
            .debounce(
                for: .milliseconds(500),
                scheduler: RunLoop.main
            )
            .removeDuplicates()
            .sink { [weak self] query in

                guard let self else {
                    return
                }

                self.searchTask?.cancel()

                guard query.isEmpty || query.count > 4 else {
                    return
                }

                self.searchTask = Task { @MainActor [weak self] in

                    guard let self else {
                        return
                    }

                    await self.getPosts()
                }
            }
            .store(in: &cancellables)
    }

    public func getPosts() async {

        isLoading = true
        error = ""

        do {

            let posts = try await service.getPost()

            if query.isEmpty {

                filteredPosts = posts

            } else {

                filteredPosts = posts.filter {
                    $0.title.localizedCaseInsensitiveContains(query) ||
                    $0.body.localizedCaseInsensitiveContains(query)
                }
            }

        } catch {

            self.error = error.localizedDescription
        }

        isLoading = false
    }

    deinit {
        searchTask?.cancel()
    }
}
