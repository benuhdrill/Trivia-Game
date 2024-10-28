//
//  ContentView.swift
//  Trivia Game
//
//  Created by Ben Gmach on 10/26/24.
//
import SwiftUI

// Trivia response structs and enum
struct TriviaResponse: Codable {
    let responseCode: Int
    let results: [TriviaQuestion]
    
    enum CodingKeys: String, CodingKey {
        case responseCode = "response_code"
        case results
    }
}

// TriviaQuestion data model
struct TriviaQuestion: Identifiable, Codable {
    var id: String { question }
    let category: String
    let type: QuestionType
    let difficulty: String
    let question: String
    let correctAnswer: String
    let incorrectAnswers: [String]
    
    enum CodingKeys: String, CodingKey {
        case category
        case type
        case difficulty
        case question
        case correctAnswer = "correct_answer"
        case incorrectAnswers = "incorrect_answers"
    }
    
    var allAnswers: [String] {
        return [correctAnswer] + incorrectAnswers.shuffled()
    }
}

enum QuestionType: String, Codable {
    case multiple
    case boolean
}

struct OptionSelectionView: View {
    @StateObject private var triviaService = TriviaService()
    @State private var numberOfQuestions = "10"
    @State private var selectedCategory = "Any Category"
    @State private var difficultyValue = 0.5
    @State private var selectedType = "Any Type"
    @State private var isTriviaGameActive = false
    @State private var selectedTimerDuration = 30
    let timeDurations = [30, 60, 120, 300, 3600] // Available options
    
    var difficultyString: String {
        if difficultyValue < 0.33 {
            return "Easy"
        } else if difficultyValue < 0.66 {
            return "Medium"
        } else {
            return "Hard"
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                let gradient = Gradient(colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.9)])
                let radialGradient = RadialGradient(gradient: gradient, center: .center, startRadius: 12, endRadius: 650)
                radialGradient.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Trivia Game")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .shadow(radius: 10)
                    
                    Form {
                        TextField("Number of Questions", text: $numberOfQuestions)
                            .keyboardType(.numberPad)
                        
                        Picker("Select Category", selection: $selectedCategory) {
                            ForEach(triviaService.categories.keys.sorted(), id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                        
                        HStack {
                            Text("Difficulty: \(difficultyString)")
                            Slider(value: $difficultyValue, in: 0...1)
                        }
                        
                        Picker("Select Type", selection: $selectedType) {
                            Text("Any Type").tag("Any Type")
                            Text("Multiple Choice").tag("Multiple")
                            Text("True or False").tag("Boolean")
                        }
                        
                        Picker("Timer Duration", selection: $selectedTimerDuration) {
                            ForEach(timeDurations, id: \.self) { duration in
                                Text(duration == 3600 ? "1 hour" : "\(duration) seconds").tag(duration)
                            }
                        }
                        
                        Button("Start Trivia") {
                            startTrivia()
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 50)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .font(.headline)
                        .cornerRadius(25)
                        .padding(.horizontal)
                        .shadow(color: .gray, radius: 5, x: 0, y: 5)
                        .disabled(triviaService.isLoading)
                        .opacity(triviaService.isLoading ? 0.5 : 1)
                        .opacity(triviaService.isLoading ? 0.5 : 1)
                    }
                    
                    NavigationLink(
                        destination: TriviaGameView(
                            triviaService: triviaService,
                            selectedTimerDuration: selectedTimerDuration
                        ),
                        isActive: $isTriviaGameActive
                    ) {
                        EmptyView()
                    }
                }
            }
        }
    }
    
    func startTrivia() {
        let selectedAmount = Int(numberOfQuestions) ?? 10
        let selectedDifficulty = difficultyString.lowercased()
        let selectedTypeKey = selectedType == "Any Type" ? "multiple" : selectedType.lowercased()
        
        triviaService.fetchTriviaQuestions(amount: selectedAmount, category: selectedCategory, difficulty: selectedDifficulty, type: selectedTypeKey)
        self.isTriviaGameActive = true
    }
}

struct TriviaGameView: View {
    @ObservedObject var triviaService: TriviaService
    @State private var userAnswers: [String: String] = [:]
    @State private var score = 0
    @State private var showingResults = false
    let selectedTimerDuration: Int
    @State private var timeRemaining: Int
    
    init(triviaService: TriviaService, selectedTimerDuration: Int) {
        self.triviaService = triviaService
        self.selectedTimerDuration = selectedTimerDuration
        // Initialize timeRemaining with the selected duration
        _timeRemaining = State(initialValue: selectedTimerDuration)
    }
    
    var body: some View {
        VStack {
            Text("Time remaining: \(timeRemaining)")
                .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                    if self.timeRemaining > 0 {
                        self.timeRemaining -= 1
                    } else {
                        self.endGame()
                    }
                }
            
            if triviaService.triviaQuestions.isEmpty {
                ProgressView("Loading...")
            } else {
                List(triviaService.triviaQuestions) { question in
                    TriviaQuestionView(question: question, userAnswer: self.$userAnswers[question.id])
                }
                
                Button("Submit") {
                    calculateScore()
                    showingResults = true
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 50)
                .background(Color.green)
                .foregroundColor(.white)
                .font(.headline)
                .cornerRadius(25)
                .padding(.horizontal)
                .disabled(triviaService.isLoading)
                .opacity(triviaService.isLoading ? 0.5 : 1)
            }
        }
        .sheet(isPresented: $showingResults) {
            ResultsView(
                score: score,
                totalQuestions: triviaService.triviaQuestions.count,
                questions: triviaService.triviaQuestions,
                userAnswers: userAnswers
            )
        }
    }
    
    func endGame() {
        calculateScore()
        showingResults = true
    }
    
    func calculateScore() {
        score = userAnswers.reduce(0) { (score, answer) -> Int in
            let questionID = answer.key
            let userAnswer = answer.value
            
            if let question = triviaService.triviaQuestions.first(where: { $0.id == questionID }),
               question.correctAnswer == userAnswer {
                return score + 1
            }
            return score
        }
    }
}

struct TriviaQuestionView: View {
    var question: TriviaQuestion
    @Binding var userAnswer: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question.question.decodingHTMLEntities)
                .font(.headline)
            
            ForEach(Array(question.allAnswers.enumerated()), id: \.offset) { index, answer in
                ChoiceView(selectedAnswer: self.$userAnswer, answer: answer, index: index)
            }
        }
        .padding()
    }
}

struct ChoiceView: View {
    @Binding var selectedAnswer: String?
    let answer: String
    let index: Int
    
    var body: some View {
        Button(action: {
            self.selectedAnswer = answer
        }) {
            HStack {
                Text("\(indexToLetter(index)). \(answer.decodingHTMLEntities)")
                    .lineLimit(nil)
                    .minimumScaleFactor(0.5)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                
                if selectedAnswer == answer {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .frame(minWidth: 0, maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .buttonStyle(PlainButtonStyle())
    }
    
    func indexToLetter(_ index: Int) -> String {
        let letters = ["A", "B", "C", "D", "E"]
        return index < letters.count ? letters[index] : "?"
    }

}

extension String {
    var decodingHTMLEntities: String {
        var result = self
        let entities = [
            "&quot;" : "\"", "&apos;" : "'", "&lt;" : "<", "&gt;" : ">", "&amp;" : "&", "&#039;" : "'", "&ndash;" : "–", "&mdash;" : "—", "&hellip;" : "…", "&pound;" : "£", "&euro;" : "€", "&copy;" : "©", "&reg;" : "®", "&prime;" : "′"
        ]
        
       
        for (key, value) in entities {
                   result = result.replacingOccurrences(of: key, with: value)
               }
               
               return result
           }
       }
#Preview {
    OptionSelectionView()
}

// Add this new view
struct ResultsView: View {
    let score: Int
    let totalQuestions: Int
    let questions: [TriviaQuestion]
    let userAnswers: [String: String]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Final Score: \(score)/\(totalQuestions)")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                    
                    ForEach(questions) { question in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(question.question.decodingHTMLEntities)
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            let userAnswer = userAnswers[question.id] ?? "No answer"
                            let isCorrect = userAnswer == question.correctAnswer
                            
                            HStack {
                                Text("Your answer: \(userAnswer.decodingHTMLEntities)")
                                Image(systemName: isCorrect ? "checkmark.circle.fill" : "x.circle.fill")
                                    .foregroundColor(isCorrect ? .green : .red)
                            }
                            
                            if !isCorrect {
                                Text("Correct answer: \(question.correctAnswer.decodingHTMLEntities)")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
