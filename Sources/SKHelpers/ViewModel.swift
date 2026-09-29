//
//  Untitled.swift
//  ViewModel
//
//  Created by Senthil on 07/09/26.
//
import Combine
import SwiftUI

public struct Post: Codable, Sendable {
    let userID: Int
    let id: Int
    let title: String
    let body: String
    
    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case id = "id"
        case title = "title"
        case body = "body"
    }
}

public protocol PostProtocol {
    func getPost() async throws -> [Post]
}

public actor PostService: PostProtocol {
    public init() {}

    public func getPost() async throws -> [Post] {
        guard let url = URL(string: "https://jsonplaceholder.typicode.com/posts")  else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let post = try JSONDecoder().decode([Post].self, from: data)
        return post
    }
}

@MainActor
public class ViewModel: ObservableObject {
    @Published var isload = false
    @Published var error = ""
    @Published var query = ""
    @Published var filteredPosts: [Post] = []
    private let service: PostService?
    private var searchTask: Task<Void, Never>?
    var cancellable = Set<AnyCancellable>()
    
    public init(service: PostService?) {
        self.service = service
        $query
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self = self else { return }
                if self.query.count == 0 || self.query.count > 4 {
                    searchTask?.cancel()
                    searchTask = Task {
                        await self.getPosts()
                    }
                }
            }
            .store(in: &cancellable)
        
    }
    
    func getPosts() async {
        self.isload = true
        do {
            let posts = try await self.service?.getPost() ?? []
            if query.isEmpty {
                self.filteredPosts = posts
            } else {
                filteredPosts = posts.filter{$0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query) }
            }
            self.isload = false
        } catch(let error) {
            self.error = error.localizedDescription
            self.isload = false
        }
    }
}
