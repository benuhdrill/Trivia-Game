//
//  TriviaService.swift
//  Trivia Game
//
//  Created by Ben Gmach on 10/26/24.
//
import Foundation
import Combine

class TriviaService: ObservableObject {
    @Published var triviaQuestions: [TriviaQuestion] = []
    @Published var isLoading: Bool = false
    @Published var categories: [String: Int] = ["Any Category": 0]
    
    private var cancellables: Set<AnyCancellable> = []
    private let baseURL = "https://opentdb.com/api.php"
    
    init() {
        fetchCategories()
    }
    
    func fetchTriviaQuestions(amount: Int, category: String, difficulty: String, type: String) {
        isLoading = true
        
        var urlComponents = URLComponents(string: baseURL)
        urlComponents?.queryItems = [
            URLQueryItem(name: "amount", value: String(amount)),
            URLQueryItem(name: "difficulty", value: difficulty),
            URLQueryItem(name: "type", value: type)
        ]
        
        if let categoryID = categories[category], categoryID != 0 {
            urlComponents?.queryItems?.append(URLQueryItem(name: "category", value: String(categoryID)))
        }
        
        guard let url = urlComponents?.url else {
            print("Invalid URL")
            isLoading = false
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: TriviaResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { completion in
                self.isLoading = false
                if case .failure(let error) = completion {
                    print("Error fetching trivia questions: \(error)")
                }
            } receiveValue: { response in
                self.triviaQuestions = response.results
            }
            .store(in: &cancellables)
    }
    
    private func fetchCategories() {
        guard let url = URL(string: "https://opentdb.com/api_category.php") else {
            print("Invalid category URL")
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: CategoryResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("Error fetching categories: \(error)")
                }
            } receiveValue: { response in
                var categoriesDict = ["Any Category": 0]
                for category in response.triviaCategories {
                    categoriesDict[category.name] = category.id
                }
                self.categories = categoriesDict
            }
            .store(in: &cancellables)
    }
}

struct CategoryResponse: Codable {
    let triviaCategories: [Category]
    
    enum CodingKeys: String, CodingKey {
        case triviaCategories = "trivia_categories"
    }
}

struct Category: Codable {
    let id: Int
    let name: String
}
